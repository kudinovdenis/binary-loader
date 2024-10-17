import KLActivityLogger
import BinaryUtils

public struct AnalyzerResult {
    
    public let reader: MemoryEditor
    public let binary: MachObjectFile
    
}

public protocol BinaryAnalyzer {
    
    func analyze() throws -> [AnalyzerResult]
    
}

public final class SimpleBinaryAnalyzer: BinaryAnalyzer {
    
    enum Constants {
        
        enum Magic {
            
            static var fatBinaryLE: UInt32 { 0xcafebabe }
            static var fatBinaryBE: UInt32 { 0xbebafeca }
            
        }
        
    }
    
    public enum Error: Swift.Error {
        case incorrectHeader
        case readWrongNumberOfBytes
        case unableToRead
        // command
        case unsupportedCommandType
        case unableToGetSegmentName
        // command -> section
        case unableToGetSectionName
        // command (Link Libraries)
        case invalidStringData
        // command (LC_BUILD_VERSION)
        case unsupportedPlatform
        case unsupportedTool
    }
    
    private let analyzerActivity: Activity
    private let fileUrl: URL
    
    public init(parentActivity: ChildActivityFactory, fileURL: URL) throws {
        analyzerActivity = parentActivity.childActivity(named: "Binary Analyzer")
        analyzerActivity.start()
        self.fileUrl = fileURL
    }
    
    deinit {
        analyzerActivity.markAsReadyToFinish()
    }
    
    public func analyze() throws -> [AnalyzerResult] {
        let filename = fileUrl.lastPathComponent
        var fileReader = try FileEditor(parentActivity: analyzerActivity, fileUrl: fileUrl)
        var magic: UInt32 = try fileReader.readNext()
        
        if magic == Constants.Magic.fatBinaryBE {
            analyzerActivity.debug("Reopening as Big Endian file")
            fileReader = try FileEditor(parentActivity: analyzerActivity, fileUrl: fileUrl, endian: .big)
        }
        
        magic = try fileReader.readNext()
        if magic == Constants.Magic.fatBinaryLE {
            // fat binary
            let machOFatBinaryHeader = MachoFatBinary.Header(magic: magic,
                                                             nArchitectures: try fileReader.readNext())
            var binaryInfos = [MachoFatBinary.SingleBinaryInfo]()
            for _ in 0..<machOFatBinaryHeader.nArchitectures {
                binaryInfos.append(try readNextBinaryInfo(fileReader: fileReader))
            }
            
            var result = [AnalyzerResult]()
            for singleBinaryInfo in binaryInfos {
                let singleBinaryFileReader = try fileReader.baseReader().child(startingAt: singleBinaryInfo.offset)
//                try analyzerActivity.debug(try singleBinaryFileReader.hexRepresentation())
                
                let binary = try parseSingleMachoBinary(filename: filename, fileReader: singleBinaryFileReader)
                result.append(AnalyzerResult(reader: try singleBinaryFileReader.baseReader(), binary: binary))
            }
            return result
        }
        else {
            // general MachO binary
            let reader = try fileReader.baseReader()
//            try analyzerActivity.debug(try reader.hexRepresentation())
            return [AnalyzerResult(reader: try reader.baseReader(),
                                   binary: try parseSingleMachoBinary(filename: filename, fileReader: reader))]
        }
    }
    
    private func readNextBinaryInfo(fileReader: FileEditor) throws -> MachoFatBinary.SingleBinaryInfo {
        return MachoFatBinary.SingleBinaryInfo(cputype: try fileReader.readNext(),
                                               cpusubtype: try fileReader.readNext(),
                                               offset: try fileReader.readNext(),
                                               size: try fileReader.readNext(),
                                               align: try fileReader.readNext())
    }
    
    private func parseSingleMachoBinary(filename: String, fileReader: FileEditor) throws -> MachObjectFile {
        let magic: UInt32 = try fileReader.readNext()
        let cpuType: UInt32 = try fileReader.readNext()
        let cpuSubType: UInt32 = try fileReader.readNext()
        let fileType: UInt32 = try fileReader.readNext()
        let numberOfLoadCommands: UInt32 = try fileReader.readNext()
        let sizeOfLoadCommands: UInt32 = try fileReader.readNext()
        let flags: UInt32 = try fileReader.readNext()
        let reserved: UInt32 = try fileReader.readNext()
        
        let header = MachOHeader(magic: magic,
                                 cpuType: cpuType,
                                 cpuSubType: cpuSubType,
                                 fileType: fileType,
                                 numberOfLoadCommands: numberOfLoadCommands,
                                 sizeOfLoadCommands: sizeOfLoadCommands,
                                 flags: MachOHeader.Flags(rawValue: flags),
                                 reserved: reserved)
        
        guard header.cpuTypeHumanReadable == .arm else {
            return MachObjectFile(header: header, commands: [], name: filename)
        }
        
        var commands: [Command] = []
        for _ in 0..<numberOfLoadCommands {
            let command = try readNextCommand(fileReader: fileReader)
            analyzerActivity.debug("Read command: \(command)")
            commands.append(command)
        }
        
        let objectFile = MachObjectFile(header: header, commands: commands, name: filename)
        analyzerActivity.debug("Parsed MachO binary: \(objectFile)")
        return objectFile
    }
    
    private func readNextCommand(fileReader: MemoryEditor) throws -> Command {
        let commandReader = try fileReader.child(startingAt: 0)
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        try fileReader.advance(by: commandHeader.size) // move to the end of command so we can read next command
        try commandReader.setVirtualOffset(0) // reset reader to start of command
        
        guard let commandType = CommandHeader.CommandType(rawValue: commandHeader.type) else {
            analyzerActivity.warning("Skip command \(commandHeader.type) for now...")
            return SkipCommand(type: commandHeader.type, size: commandHeader.size)
//            throw Error.unsupportedCommandType
        }
        
        switch (commandType) {
        case .LC_SEGMENT_64:
            return try readLcLoadSegment(commandReader: commandReader)
            
        case .LC_LOAD_DYLIB,
                .LC_LOAD_WEAK_DYLIB,
                .LC_REEXPORT_DYLIB:
            return try readLoadDylibCommand(commandReader: commandReader)
            
        case .LC_BUILD_VERSION:
            return try readLcBuildVersion(commandReader: commandReader)
            
        case .LC_SOURCE_VERSION,
                .LC_ENCRYPTION_INFO_64,
                .LC_ID_DYLIB,
                .LC_SEGMENT_SPLIT_INFO:
            analyzerActivity.warning("Skip command \(commandType) for now...")
            return SkipCommand(type: commandHeader.type, size: commandHeader.size)
            
        case .LC_DYLD_CHAINED_FIXUPS:
            return try readLcDyldChainedFixups(commandReader: commandReader, binaryStartReader: fileReader)
        
        case .LC_SYMTAB:
            return try readLcSymTab(commandReader: commandReader, binaryStartReader: fileReader)
            
        case .LC_LOAD_DYLINKER:
            return try readLcLoadDylinker(commandReader: commandReader)
            
        case .LC_UUID:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let uuid = try commandReader.readNext(16)
            return LCUuid(type: commandHeader.type, size: commandHeader.size, uuid: uuid)
            
        case .LC_MAIN:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let command = LcMain(type: commandHeader.type,
                                 size: commandHeader.size,
                                 entryOffset: try commandReader.readNext(),
                                 stackSize: try commandReader.readNext())
            return command
            
        case .LC_RPATH:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let offset: UInt32 = try commandReader.readNext()
            try commandReader.setVirtualOffset(offset)
            let path = try commandReader.readString(size: UInt64(commandHeader.size - offset))
            let command = LcRPath(type: commandHeader.type, size: commandHeader.size, path: path)
            return command
            
        case .LC_DYSYMTAB:
            return try parseLcDySymTabCommand(commandReader: commandReader, fileReader: fileReader)
            
        case .LC_FUNCTION_STARTS:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let command = LcFunctionStarts(type: commandHeader.type,
                                           size: commandHeader.size,
                                           dataOffset: try commandReader.readNext(),
                                           dataSize: try commandReader.readNext())
            return command
            
        case .LC_DATA_IN_CODE:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let command = LcDataInCode(type: commandHeader.type,
                                       size: commandHeader.size,
                                       dataOffset: try commandReader.readNext(),
                                       dataSize: try commandReader.readNext())
            return command
            
        case .LC_CODE_SIGNATURE:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let command = LcCodeSignature(type: commandHeader.type,
                                          size: commandHeader.size,
                                          dataOffset: try commandReader.readNext(),
                                          dataSize: try commandReader.readNext())
            return command
            
        case .LC_DYLD_EXPORTS_TRIE:
            let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
            let command = LcDyldExportsTrie(type: commandHeader.type,
                                            size: commandHeader.size,
                                            dataOffset: try commandReader.readNext(),
                                            dataSize: try commandReader.readNext())
            return command
        }
    }
    
    private func readLcLoadDylinker(commandReader: MemoryEditor) throws -> LCLoadDylinker {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let linkerPathOffset: UInt32 = try commandReader.readNext()
        let linkerPathSize = commandHeader.size - CommandHeader.sizeInBytes - UInt32(linkerPathOffset.sizeInBytes)
        
        try commandReader.setVirtualOffset(linkerPathOffset)
        let linkerPath = try commandReader.readString(size: UInt64(linkerPathSize))
        
        let command = LCLoadDylinker(type: commandHeader.type, size: commandHeader.size, dynamicLinkerPath: linkerPath)
        return command
    }
    
    private func readLcSymTab(commandReader: MemoryEditor, binaryStartReader: MemoryEditor) throws -> LCSymTab {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let symbolTableOffset: UInt32 = try commandReader.readNext()
        let numberOfSymbolTableEntries: UInt32 = try commandReader.readNext()
        let stringTableOffset: UInt32 = try commandReader.readNext()
        let stringTableSize: UInt32 = try commandReader.readNext()
        
        let symbolsTableReader = try binaryStartReader.baseReader().child(startingAt: symbolTableOffset)
        var symtabEntries = [SymTabEntry]()
        for _ in 0..<numberOfSymbolTableEntries {
            let indexIntoStringTable: UInt32 = try symbolsTableReader.readNext()
            let typeFlag: UInt8 = try symbolsTableReader.readNext()
            let sectionNumber: UInt8 = try symbolsTableReader.readNext()
            let desc: UInt16 = try symbolsTableReader.readNext()
            let valueOfSymbol: UInt64 = try symbolsTableReader.readNext()
            
            let stringTableReader = try binaryStartReader.baseReader().child(startingAt: stringTableOffset + indexIntoStringTable)
            let symbolName = try stringTableReader.readNextNullTerminatedString()
            
            let symtabEntry = SymTabEntry(indexIntoStringTable: indexIntoStringTable,
                                          typeFlag: typeFlag,
                                          sectionNumber: sectionNumber,
                                          desc: desc,
                                          valueOfSymbol: valueOfSymbol,
                                          additional: SymTabEntry.Additional(symbolName: symbolName, typeFlag: typeFlag))
            symtabEntries.append(symtabEntry)
            analyzerActivity.debug("Now we know about symbol: \(symbolName): \(symtabEntry.additional.location(symtabEntry))")
        }
        
        let infoForLinker = LCSymTab.InfoForLinker(symbols: symtabEntries.map { $0.toInfoForLinker })
        let command = LCSymTab(type: commandHeader.type,
                               size: commandHeader.size,
                               symbolTableOffset: symbolTableOffset,
                               numberOfSymbolTableEntries: numberOfSymbolTableEntries,
                               stringTableOffset: stringTableOffset,
                               stringTableSize: stringTableSize,
                               symtabEntries: symtabEntries,
                               infoForLinker: infoForLinker)
        return command
    }
    
    private func readLcBuildVersion(commandReader: MemoryEditor) throws -> LCBuildVersionCommand {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let platformRaw: UInt32 = try commandReader.readNext()
        guard let platform = LCBuildVersionCommand.Platform(rawValue: platformRaw) else {
            throw Error.unsupportedPlatform
        }
        let minOS: UInt32 = try commandReader.readNext()
        let sdk: UInt32 = try commandReader.readNext()
        let nTools: UInt32 = try commandReader.readNext()
        
        var tools = [LCBuildVersionCommand.BuildToolVersion]()
        for _ in 0..<nTools {
            let toolTypeRaw: UInt32 = try commandReader.readNext()
            guard let toolType = LCBuildVersionCommand.BuildToolVersion.Tool(rawValue: toolTypeRaw) else {
                throw Error.unsupportedTool
            }
            let tool = LCBuildVersionCommand.BuildToolVersion(tool: toolType, version: try commandReader.readNext())
            tools.append(tool)
        }
            
        let command = LCBuildVersionCommand(type: commandHeader.type,
                                            size: commandHeader.size,
                                            platform: platform,
                                            minos: minOS,
                                            sdk: sdk,
                                            ntools: nTools,
                                            tools: tools)
        return command
    }
    
    private func readLoadDylibCommand(commandReader: MemoryEditor) throws -> LinkLibraryCommand {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let stringOffset: UInt32 = try commandReader.readNext()
        let timeDateStamp: UInt32 = try commandReader.readNext()
        let currentVersion: UInt32 = try commandReader.readNext()
        let compatibleVersion: UInt32 = try commandReader.readNext()
        let filePathSize = commandHeader.size - stringOffset
        let filePath = try commandReader.readString(size: UInt64(filePathSize))
        
        try commandReader.setVirtualOffset(stringOffset)
        let dylibName = try commandReader.readNextNullTerminatedString()
        
        let command = LinkLibraryCommand(type: commandHeader.type,
                                         size: commandHeader.size,
                                         linkType: .init(commandType: CommandHeader.CommandType(rawValue: commandHeader.type)!),
                                         stringOffset: stringOffset,
                                         timeDateStamp: timeDateStamp,
                                         currentVersion: currentVersion,
                                         compatibleVersion: compatibleVersion,
                                         filePathString: filePath,
                                         additional: LinkLibraryCommand.Additional(dylibName: dylibName,
                                                                                   isReexport: commandHeader.type == CommandHeader.CommandType.LC_REEXPORT_DYLIB.rawValue))
        return command
    }
    
    private func readLcLoadSegment(commandReader: MemoryEditor) throws -> LcSegment64 {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let segmentName = try commandReader.readString(size: 16)
        let address: UInt64 = try commandReader.readNext()
        let addressSize: UInt64 = try commandReader.readNext()
        let fileOffset: UInt64 = try commandReader.readNext()
        let sizeFromFileOffset: UInt64 = try commandReader.readNext()
        let maxVMProtections: UInt32 = try commandReader.readNext()
        let initialVMProtections: UInt32 = try commandReader.readNext()
        let numberOfSections: UInt32 = try commandReader.readNext()
        let flag32: UInt32 = try commandReader.readNext()
        
        var sections = [LcSegment64.Section]()
        for _ in 0..<numberOfSections {
            let section = LcSegment64.Section(sectname: try commandReader.readString(size: 16),
                                              segname: try commandReader.readString(size: 16),
                                              addr: try commandReader.readNext(),
                                              size: try commandReader.readNext(),
                                              offset: try commandReader.readNext(),
                                              align: try commandReader.readNext(),
                                              relocationsFileOffset: try commandReader.readNext(),
                                              numberOfRelocations: try commandReader.readNext(),
                                              flag: try commandReader.readNext(),
                                              reserved1: try commandReader.readNext(),
                                              reserved2: try commandReader.readNext(),
                                              reserved3: try commandReader.readNext())
            sections.append(section)
        }
        
        let command = LcSegment64(type: commandHeader.type,
                                  size: commandHeader.size,
                                  segname: segmentName,
                                  vmaddr: address,
                                  vmsize: addressSize,
                                  fileoff: fileOffset,
                                  filesize: sizeFromFileOffset,
                                  maxprot: LcSegment64.VMPermissions(rawValue: maxVMProtections),
                                  initprot: LcSegment64.VMPermissions(rawValue: initialVMProtections),
                                  numberOfSections: numberOfSections,
                                  flag32: LcSegment64.Flags(rawValue: flag32),
                                  sections: sections)
        return command
    }
    
    private func readLcDyldChainedFixups(commandReader: MemoryEditor, binaryStartReader: MemoryEditor) throws -> LcDyldChainedFixups {
        let activity = analyzerActivity.childActivity(named: "Chained fixups")
        activity.start()
        defer { activity.markAsReadyToFinish() }
        
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let dataOffset: UInt32 = try commandReader.readNext() // not documented
        let dataSize: UInt32 = try commandReader.readNext() // not documented
        
        struct dyld_chained_fixups_header {
            let version: UInt32
            let startsOffset: UInt32 // offset to dyld_chained_starts_in_image structure
            let importsOffset: UInt32 // Offset to list of imported symbols
            let symbolsStringTableOffset: UInt32 // Offset to string table for symbols
            let nImportedSymbols: UInt32
            let importsFormat: UInt32 // Format of the imports table/
            let symbolsFormat: UInt32
        }
        
        let headerReader = try binaryStartReader.baseReader().child(startingAt: dataOffset)
        let header = dyld_chained_fixups_header(version: try headerReader.readNext(),
                                                startsOffset: try headerReader.readNext(),
                                                importsOffset: try headerReader.readNext(),
                                                symbolsStringTableOffset: try headerReader.readNext(),
                                                nImportedSymbols: try headerReader.readNext(),
                                                importsFormat: try headerReader.readNext(),
                                                symbolsFormat: try headerReader.readNext())
        
        guard header.symbolsFormat == 0 else {
            // see https://opensource.apple.com/source/xnu/xnu-7195.81.3/EXTERNAL_HEADERS/mach-o/fixup-chains.h.auto.html
            activity.failure("Symbols are compressed with zlib")
            throw Error.unsupportedCommandType
        }
        
        // Read starts payload
        // (base + dataOff) + 0x20 = startsOffsetReader.realOffset
        let startsOffsetReader = try headerReader.baseReader().child(startingAt: header.startsOffset)
        let segmentsCount: UInt32 = try startsOffsetReader.readNext()
        var infoForLinkerRebases = [LcDyldChainedFixups.InfoForLinker.Rebase]()
        var infoForLinkerBindings = [LcDyldChainedFixups.InfoForLinker.Bind]()
        for segmentIndex in 0..<segmentsCount {
            let segmentInfoOffset: UInt32 = try startsOffsetReader.readNext()
            if segmentInfoOffset == 0 {
                continue
            }
            
            // read segment payload
            let startsInSegmentReader = try startsOffsetReader.baseReader().child(startingAt: segmentInfoOffset)
            
            struct dyld_chained_starts_in_segment {
                let size: UInt32               // size of this (amount kernel needs to copy)
                let page_size: UInt16          // 0x1000 or 0x4000
                let pointer_format: UInt16     // DYLD_CHAINED_PTR_*
                let segment_offset: UInt64     // offset in memory to start of segment
                let max_valid_pointer: UInt32  // for 32-bit OS, any value beyond this is not a pointer
                let page_count: UInt16         // how many pages are in array
            }
            
            let chainedStartsInSegment = dyld_chained_starts_in_segment(size: try startsInSegmentReader.readNext(), 
                                                                        page_size: try startsInSegmentReader.readNext(),
                                                                        pointer_format: try startsInSegmentReader.readNext(),
                                                                        segment_offset: try startsInSegmentReader.readNext(),
                                                                        max_valid_pointer: try startsInSegmentReader.readNext(),
                                                                        page_count: try startsInSegmentReader.readNext())
            
            // Imports
            struct dyld_chained_import {
                let lib_ordinal: UInt32
                let weak_import: UInt32
                let name_offset: UInt32
            }
            let importsReader = try headerReader.baseReader().child(startingAt: header.importsOffset)
            var allImports = [dyld_chained_import]()
            activity.debug("All imports:")
            for _ in 0..<header.nImportedSymbols {
                let importRaw: UInt32 = try importsReader.readNext()
                let `import` = dyld_chained_import(lib_ordinal: (importRaw & 0xFF),
                                                   weak_import: (importRaw >> 8) & 0x1,
                                                   name_offset: (importRaw >> 9) & 0x7FFFFF)
                allImports.append(`import`)
                let symbolReader = try headerReader.baseReader().child(startingAt: header.symbolsStringTableOffset + `import`.name_offset)
                let symbolName = try symbolReader.readNextNullTerminatedString()
                activity.debug("Ordinal: \(`import`.lib_ordinal), weak: \(`import`.weak_import == 1), name: \(symbolName)")
            }
            
            //
            
            let DYLD_CHAINED_PTR_64: UInt16 = 2
            let DYLD_CHAINED_PTR_64_OFFSET: UInt16 = 6
            let DYLD_CHAINED_PTR_ARM64E_USERLAND24: UInt16 = 12
            for pageIndex in 0..<chainedStartsInSegment.page_count {
                let pageStartOffset: UInt16 = try startsInSegmentReader.readNext()
                if pageStartOffset == 0xFFFF {
                    continue // does not contain any fixups
                }
                
                // returns next
                func readNextBindArm64E(chainReader: MemoryEditor, binaryStartReader: MemoryEditor, imports: [dyld_chained_import]) throws -> UInt64 {
                    let chainAddress = chainReader.realOffset
                    let chainedPtrValue: UInt64 = try chainReader.readNext()
                    let isAuth = ((chainedPtrValue >> 63) & 0x1) == 1
                    if isAuth {
                        struct dyld_chained_ptr_arm64e_bind24
                        {
                            let ordinal: UInt64
                            let zero: UInt64
                            let addend: UInt64
                            let next: UInt64
                            let bind: UInt64
                            let auth: UInt64
                        }
                        let value = dyld_chained_ptr_arm64e_bind24(ordinal: chainedPtrValue & 0xFFFFFF,
                                                                   zero: (chainedPtrValue >> 24) & 0xFF,
                                                                   addend: (chainedPtrValue >> 32) & 0x7FFFF,
                                                                   next: (chainedPtrValue >> 51) & 0x7FF,
                                                                   bind: (chainedPtrValue >> 62) & 0x1,
                                                                   auth: (chainedPtrValue >> 63) & 0x1)
                        if  value.bind == 1 {
                            if value.ordinal == 11304877 {
                                activity.error("Skip broken bind: \(value)")
                                return value.next
                            }
                            let desiredImport = imports[numericCast(value.ordinal)]
                            let symbolReader = try headerReader.baseReader().child(startingAt: header.symbolsStringTableOffset + desiredImport.name_offset)
                            let symbolName = try symbolReader.readNextNullTerminatedString()
                            infoForLinkerBindings.append(LcDyldChainedFixups.InfoForLinker.Bind(segmentIndex: segmentIndex,
                                                                                                offsetInSegment: chainAddress,
                                                                                                libraryIndexContainingSymbol: desiredImport.lib_ordinal,
                                                                                                symbolName: symbolName))
                            activity.debug("Chained fixups: Need to BIND Symbol. Offset: \(chainAddress.hexRepresentation) Lib ordinal: \(desiredImport.lib_ordinal) Name: \(symbolName)")
                        }
                        else {
                            infoForLinkerRebases.append(LcDyldChainedFixups.InfoForLinker.Rebase(segmentIndex: 0, 
                                                                                                 offsetInSegment: chainAddress,
                                                                                                 addressToRebase: value.ordinal))
                            activity.debug("Chained fixups: Need to REBASE: Target:\(value.ordinal.hexRepresentation)")
                        }
                        return value.next
                    }
                    else {
                        struct dyld_chained_ptr_arm64e_auth_bind24
                        {
                            let ordinal: UInt64
                            let zero: UInt64
                            let diversity: UInt64
                            let addrDiv: UInt64
                            let key: UInt64
                            let next: UInt64
                            let bind: UInt64
                            let auth: UInt64
                        };
                        let value = dyld_chained_ptr_arm64e_auth_bind24(ordinal: chainedPtrValue & 0xFFFFFF,
                                                                        zero: (chainedPtrValue >> 24) & 0xFF,
                                                                        diversity: (chainedPtrValue >> 32) & 0xFFFF,
                                                                        addrDiv: (chainedPtrValue >> 48) & 0x1,
                                                                        key: (chainedPtrValue >> 49) & 0x3,
                                                                        next: (chainedPtrValue >> 51) & 0x7FF,
                                                                        bind: (chainedPtrValue >> 62) & 0x1,
                                                                        auth: (chainedPtrValue >> 63) & 0x1)
                        if value.bind == 1 {
                            let desiredImport = imports[numericCast(value.ordinal)]
                            let symbolReader = try headerReader.baseReader().child(startingAt: header.symbolsStringTableOffset + desiredImport.name_offset)
                            let symbolName = try symbolReader.readNextNullTerminatedString()
                            infoForLinkerBindings.append(LcDyldChainedFixups.InfoForLinker.Bind(segmentIndex: segmentIndex,
                                                                                                offsetInSegment: chainAddress,
                                                                                                libraryIndexContainingSymbol: desiredImport.lib_ordinal,
                                                                                                symbolName: symbolName))
                            activity.debug("Chained fixups: Need to BIND Symbol. Offset: \(chainAddress.hexRepresentation) Lib ordinal: \(desiredImport.lib_ordinal) Name: \(symbolName)")
                        }
                        else {
                            infoForLinkerRebases.append(LcDyldChainedFixups.InfoForLinker.Rebase(segmentIndex: 0,
                                                                                                 offsetInSegment: chainAddress,
                                                                                                 addressToRebase: value.ordinal))
                            activity.debug("Chained fixups: Need to REBASE: Target:\(value.ordinal.hexRepresentation)")
                        }
                        return value.next
                    }
                }
                
                struct dyld_chained_ptr_64_bind {
                    let ordinal: UInt64
                    let addend: UInt64
                    let reserved: UInt64
                    let next: UInt64
                    let bind: UInt64
                }
                
                func readNextBind(chainReader: MemoryEditor, binaryStartReader: MemoryEditor, imports: [dyld_chained_import], pointerType: UInt16) throws -> dyld_chained_ptr_64_bind {
                    // chain address needs to be adjusted in case of fat binary where it points to FAT file instead of binary for architecture.
                    let chainAddress = chainReader.realOffset - (try binaryStartReader.baseReader().realOffset)
                    let chainedPtrValue: UInt64 = try chainReader.readNext()
                    let bind = dyld_chained_ptr_64_bind(ordinal: chainedPtrValue & 0xFFFFFF,
                                                        addend: (chainedPtrValue >> 24) & 0xFF,
                                                        reserved: (chainedPtrValue >> 32) & 0x7FFFF,
                                                        next: (chainedPtrValue >> 51) & 0xFFF,
                                                        bind: (chainedPtrValue >> 63) & 0x1)
                    
                    // The LC_DYLD_CHAINED_FIXUPS command includes fixups for both rebasing (updating memory addresses)
                    // and binding (resolving external symbols).
                    if bind.bind == 1 {
                        if bind.ordinal == 10079033 {
                            activity.error("Skip broken bind: \(bind)")
                            return bind
                        }
                        let desiredImport = imports[numericCast(bind.ordinal)]
                        let symbolReader = try headerReader.baseReader().child(startingAt: header.symbolsStringTableOffset + desiredImport.name_offset)
                        let symbolName = try symbolReader.readNextNullTerminatedString()
                        infoForLinkerBindings.append(LcDyldChainedFixups.InfoForLinker.Bind(segmentIndex: segmentIndex, 
                                                                                            offsetInSegment: chainAddress,
                                                                                            libraryIndexContainingSymbol: desiredImport.lib_ordinal,
                                                                                            symbolName: symbolName))
                        activity.debug("Chained fixups: Need to BIND Symbol. Offset: \(chainAddress.hexRepresentation) Lib ordinal: \(desiredImport.lib_ordinal) Name: \(symbolName)")
                    }
                    else {
                        // rebase (probably onto segment's loaded base address)
                        struct dyld_chained_ptr_64_rebase
                        {
                            let target: UInt64    // 64GB max image size (DYLD_CHAINED_PTR_64 => vmAddr, DYLD_CHAINED_PTR_64_OFFSET => runtimeOffset)
                            let high8: UInt64    // top 8 bits set to this (DYLD_CHAINED_PTR_64 => after slide added, DYLD_CHAINED_PTR_64_OFFSET => before slide added)
                            let reserved: UInt64    // all zeros
                            let next: UInt64    // 4-byte stride
                            let bind: UInt64    // == 0
                        };
                        
                        let rebaseBind = dyld_chained_ptr_64_rebase(target: chainedPtrValue & 0xFFFFFFFFF,
                                                                    high8: (chainedPtrValue >> 36) & 0xFF,
                                                                    reserved: (chainedPtrValue >> 44) & 0x7F,
                                                                    next: (chainedPtrValue >> 51) & 0xFFF,
                                                                    bind: (chainedPtrValue >> 63) & 0x1)
                        if pointerType == DYLD_CHAINED_PTR_64 {
                            infoForLinkerRebases.append(LcDyldChainedFixups.InfoForLinker.Rebase(segmentIndex: segmentIndex,
                                                                                                 offsetInSegment: chainAddress,
                                                                                                 addressToRebase: rebaseBind.target))
                            activity.debug("Chained fixups: Need to REBASE: Target:\(rebaseBind.target.hexRepresentation)")
                        }
                        else if pointerType == DYLD_CHAINED_PTR_64_OFFSET {
                            infoForLinkerRebases.append(LcDyldChainedFixups.InfoForLinker.Rebase(segmentIndex: segmentIndex,
                                                                                                 offsetInSegment: chainAddress,
                                                                                                 addressToRebase: UInt64(rebaseBind.high8 << 36) | rebaseBind.target))
                            activity.debug("Chained fixups: Need to REBASE: Target:\(rebaseBind.target.hexRepresentation)")
                        }
                        else {
                            activity.failure("Unexpected pointer type for bind")
                        }
                    }
                    return bind
                }
                
                let pageReader = try binaryStartReader
                    .baseReader()
                    .child(startingAt: chainedStartsInSegment.segment_offset + UInt64(chainedStartsInSegment.page_size) * UInt64(pageIndex) + UInt64(pageStartOffset))
                
                switch chainedStartsInSegment.pointer_format {
                case DYLD_CHAINED_PTR_64,
                    DYLD_CHAINED_PTR_64_OFFSET:
                    var reader = pageReader
                    var bind = try readNextBind(chainReader: reader, 
                                                binaryStartReader: binaryStartReader,
                                                imports: allImports,
                                                pointerType: chainedStartsInSegment.pointer_format)
                    while bind.next != 0 {
                        reader = try reader.baseReader().child(startingAt: bind.next * 4)
                        bind = try readNextBind(chainReader: reader, 
                                                binaryStartReader: binaryStartReader,
                                                imports: allImports,
                                                pointerType: chainedStartsInSegment.pointer_format)
                    }
                    
                case DYLD_CHAINED_PTR_ARM64E_USERLAND24:
                    var reader = pageReader
                    var next = try readNextBindArm64E(chainReader: reader, binaryStartReader: binaryStartReader, imports: allImports)
                    while next != 0 {
                        reader = try reader.baseReader().child(startingAt: next * 8)
                        next = try readNextBindArm64E(chainReader: reader, binaryStartReader: binaryStartReader, imports: allImports)
                    }
                    
                default:
                    // FIXME: IMPORTANT
                    activity.warning("Unsupported type of pointer format: \(chainedStartsInSegment.pointer_format)")
//                    activity.failure("Unsupported type of pointer format: \(chainedStartsInSegment.pointer_format)")
                }
            }
        }
        
        let command = LcDyldChainedFixups(type: commandHeader.type, 
                                          size: commandHeader.size,
                                          infoForLinker: LcDyldChainedFixups.InfoForLinker(rebases: infoForLinkerRebases,
                                                                                           binds: infoForLinkerBindings))
        return command
    }
    
    private func parseLcDySymTabCommand(commandReader: MemoryEditor, fileReader: MemoryEditor) throws -> LcDySymTab {
        let commandHeader = CommandHeader(type: try commandReader.readNext(), size: try commandReader.readNext())
        
        let ilocalsym: UInt32 = try commandReader.readNext()
        let nlocalsym: UInt32 = try commandReader.readNext()
        let iextdefsym: UInt32 = try commandReader.readNext()
        let nextdefsym: UInt32 = try commandReader.readNext()
        let iundefsym: UInt32 = try commandReader.readNext()
        let nundefsym: UInt32 = try commandReader.readNext()
        let tocoff: UInt32 = try commandReader.readNext()
        let ntoc: UInt32 = try commandReader.readNext()
        let modtaboff: UInt32 = try commandReader.readNext()
        let nmodtab: UInt32 = try commandReader.readNext()
        let extrefsymoff: UInt32 = try commandReader.readNext()
        let nextrefsyms: UInt32 = try commandReader.readNext()
        let indirectsymoff: UInt32 = try commandReader.readNext()
        let nindirectsyms: UInt32 = try commandReader.readNext()
        let extreloff: UInt32 = try commandReader.readNext()
        let nextrel: UInt32 = try commandReader.readNext()
        let locreloff: UInt32 = try commandReader.readNext()
        let nlocrel: UInt32 = try commandReader.readNext()
        
        // Indirect symbols table
        let indirectSymbolsReader = try fileReader.baseReader().child(startingAt: indirectsymoff)
        var indirectSymbols = [UInt32]()
        for _ in 0..<nindirectsyms {
            let symbol: UInt32 = try indirectSymbolsReader.readNext()
            indirectSymbols.append(symbol)
        }
        
        let command = LcDySymTab(type: commandHeader.type,
                                 size: commandHeader.size,
                                 ilocalsym: ilocalsym,
                                 nlocalsym: nlocalsym,
                                 iextdefsym: iextdefsym,
                                 nextdefsym: nextdefsym,
                                 iundefsym: iundefsym,
                                 nundefsym: nundefsym,
                                 tocoff: tocoff,
                                 ntoc: ntoc,
                                 modtaboff: modtaboff,
                                 nmodtab: nmodtab,
                                 extrefsymoff: extrefsymoff,
                                 nextrefsyms: nextrefsyms,
                                 indirectsymoff: indirectsymoff,
                                 nindirectsyms: nindirectsyms,
                                 extreloff: extreloff,
                                 nextrel: nextrel,
                                 locreloff: locreloff,
                                 nlocrel: nlocrel,
                                 additional: LcDySymTab.Additional(indirectSymbols: indirectSymbols))
        return command
    }
    
}
