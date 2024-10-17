import BinaryAnalyzer
import BinaryUtils
import KLActivityLogger

final class DeinitForStruct {
    
    let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
    
    deinit {
        self.closure()
    }
    
}

public class SymbolsTable {
    public var symbols: [String: UInt64]
    
    init(symbols: [String : UInt64]) {
        self.symbols = symbols
    }
}

public protocol LoadedBinary {
    var name: String { get }
    var ram: RamEditor { get }
    var symbolsTable: SymbolsTable { get }
    var objectFile: MachObjectFile { get }
    var sections: [RamEditor] { get }
}

public struct LoadedExecutable: LoadedBinary {
    public struct EntryPoint {
        public let address: Int
    }
    
    public let name: String
    public let ram: RamEditor
    public let entrypoint: EntryPoint
    public let symbolsTable: SymbolsTable
    public let objectFile: MachObjectFile
    public let sections: [RamEditor]
}

public struct LoadedLibrary: LoadedBinary {
    public let name: String
    public let ram: RamEditor
    public let symbolsTable: SymbolsTable
    public let objectFile: MachObjectFile
    public let sections: [RamEditor]
}

public final class LoadedLibrariesStorage {
    
    public typealias Result = (LoadedLibrary, UInt64)
    
    public var loadedLibraries: [String: LoadedLibrary] = [:]
    
    public init() {
        // Do nothing
    }
    
    public func lookupSymbol(_ name: String) -> Result? {
        for library in loadedLibraries.values {
            if let address = library.symbolsTable.symbols[name] {
                return (library, address)
            }
        }
        return nil
    }
    
}

public final class Loader {
    
    enum Error: Swift.Error {
        case unableToLocateLcMainCommand
        case unableToLocateLcDySymTabCommand
        case unableToLocateLcSymTabCommand
        
        case unableToGetBaseRamAddress
        case unableToSetMemoryProtection(rawError: Int32)
        case missmatchingCommandAndCommandType
        case unableToParseDependency
        case noMatchingArchInLibrary
    }
    
    enum Constants {
        static var dependenciesPath = "/path/to/dependencies/root"
    }
    
    private let loaderActivity: Activity
    private let deinitHelper: DeinitForStruct
    private let externaFunctionImplementations: [String: Int]
    private var loadedLibrariesStorage: LoadedLibrariesStorage
    private let objectFile: MachObjectFile
    private let objectFileReader: MemoryEditor
    private var symbolsTable = [String: UInt64]()
    
    public init(parentActivity: ChildActivityFactory, 
                externaFunctionImplementations: [String: Int],
                objectFile: MachObjectFile,
                objectFileReader: MemoryEditor,
                loadedLibrariesStorage: LoadedLibrariesStorage) {
        let activity = parentActivity.childActivity(named: "Loader")
        self.loaderActivity = activity
        self.loaderActivity.start()
        self.objectFile = objectFile
        self.objectFileReader = objectFileReader
        self.loadedLibrariesStorage = loadedLibrariesStorage
        
        self.externaFunctionImplementations = externaFunctionImplementations
        
        deinitHelper = DeinitForStruct {
            activity.markAsReadyToFinish()
        }
    }
    
    public func load() throws -> LoadedBinary {
        // At first just load everything in RAM
        let binary = try loadIntoMemory()
        
        // Fill symbols table
        var visited = [String: Bool]()
        try fillSymbolsTable(for: binary, visited: &visited)
        
        // Then resolve all dependencies
        try resolveExternals(binary: binary)
        
        // Set memory protection
        // We can't set protection earlier because we need
        // to write to segments while resolving symbols
        try setMemoryProtection(binary: binary)
        for library in loadedLibrariesStorage.loadedLibraries {
            try setMemoryProtection(binary: library.value)
        }
        
        return binary
    }
    
    private func fillSymbolsTable(for binary: LoadedBinary, visited: inout [String: Bool]) throws {
        if visited[binary.name] == true {
            return
        }
        
        var symtab = [String: UInt64]()
        // own
        for symtabCmd in binary.objectFile.getLcSymTabCommands() {
            for entry in symtabCmd.infoForLinker.symbols {
                switch entry {
                case .undefined(let symbolName, let offsetToWriteAddress):
                    loaderActivity.warning("Need to resolve symbol: \(symbolName), offset: \(offsetToWriteAddress.hexRepresentation)")
                    
                case .publicExternal(let symbolName, let addressRelativeToStartOfSection, let sectionNumber):
                    guard sectionNumber != 0x0 else {
                        loaderActivity.error("NO_SECT (\(symbolName)")
                        continue
                    }
                    let section = binary.sections[sectionNumber - 1]
                    let baseRamAddress = UInt64(Int(bitPattern: try section.baseReader().baseAddress))
                    let newAddress = baseRamAddress + addressRelativeToStartOfSection - (binary.objectFile.isExecutable ? 0x100000000 : 0)
                    loaderActivity.verbose("Adding symbol \(symbolName) to symtab for bin \(binary.name) address \(newAddress.hexRepresentation) binary starts at \(binary.ram.baseAddress)")
                    symtab[symbolName] = newAddress
                    
                case .privateExternal(let symbolName, let addressRelativeToStartOfSection, let sectionNumber):
                    guard sectionNumber != 0x0 else {
                        loaderActivity.error("NO_SECT (\(symbolName)")
                        continue
                    }
                    let section = binary.sections[sectionNumber - 1]
                    let baseRamAddress = UInt64(Int(bitPattern: try section.baseReader().baseAddress))
                    let newAddress = baseRamAddress + addressRelativeToStartOfSection - (binary.objectFile.isExecutable ? 0x100000000 : 0)
                    loaderActivity.verbose("Adding symbol \(symbolName) to symtab for bin \(binary.name) address \(newAddress.hexRepresentation) binary starts at \(binary.ram.baseAddress)")
                    symtab[symbolName] = newAddress
                    
                case .debugStab(symbolName: let symbolName):
                    loaderActivity.info("Debug symbol: \(symbolName)")
                    
                case .absolute(let symbolName, let address):
                    // TODO: Should such symbol appear in symtab?
                    loaderActivity.info("Absoulte symbol: \(symbolName) at address: \(address.hexRepresentation)")
                }
            }
        }
        
        // reexported
        for reexportCmd in binary.objectFile.getLcLoadDylibReexportCommands() {
            guard let dependencyUrl = URL(string: reexportCmd.filePathString) else {
                throw Error.unableToParseDependency
            }
            
            let dependencyName = dependencyUrl.lastPathComponent
            
            guard let loadedDependency = loadedLibrariesStorage.loadedLibraries[dependencyName] else {
                throw Error.unableToParseDependency
            }
            
            try fillSymbolsTable(for: loadedDependency, visited: &visited)
            
            for entry in loadedDependency.symbolsTable.symbols {
                symtab[entry.key] = entry.value
            }
        }
        
        // Repeat for every dependency
        for dependency in binary.objectFile.getLcLoadDylibCommands() {
            guard let dependencyUrl = URL(string: dependency.filePathString) else {
                throw Error.unableToParseDependency
            }
            
            let dependencyName = dependencyUrl.lastPathComponent
            
            guard let loadedDependency = loadedLibrariesStorage.loadedLibraries[dependencyName] else {
                throw Error.unableToParseDependency
            }
            
            try fillSymbolsTable(for: loadedDependency, visited: &visited)
        }
        
        binary.symbolsTable.symbols = symtab
        visited[binary.name] = true
    }
    
    private func resolveExternals(binary: LoadedBinary) throws {
        var visited = [String: Bool]()
        try resolveExternals(loadedBinary: binary, visited: &visited)
    }
    
    private func setMemoryProtection(binary: LoadedBinary) throws {
        // Call mprotect
        let protection = PROT_READ | PROT_EXEC
        let result = mprotect(binary.ram.baseAddress, Int(binary.ram.size), protection)
        if result != 0 {
            throw Error.unableToSetMemoryProtection(rawError: errno)
        }
    }
    
    private func loadIntoMemory() throws -> LoadedBinary {
        let binary = try loadMachoBinary()
        if let library = binary as? LoadedLibrary {
            loadedLibrariesStorage.loadedLibraries[library.name] = library
        }
        try objectFile.getLcLoadDylibCommands().forEach { dependency in
            let libraryPath = dependency.filePathString
            let prefixPath = URL(fileURLWithPath: Constants.dependenciesPath)
            let url = prefixPath.appendingPathComponent(libraryPath)
            let libraryName = url.lastPathComponent
            if loadedLibrariesStorage.loadedLibraries[libraryName] != nil {
                loaderActivity.info("Library \(libraryName) is already loaded")
                return
            }
            let binaryAnalyzer = try SimpleBinaryAnalyzer(parentActivity: loaderActivity, fileURL: url)
            let parsedLibrary = try binaryAnalyzer.analyze()
            guard let arm64Binary = parsedLibrary.first(where: { $0.binary.isArm64 }) else {
                throw Error.noMatchingArchInLibrary
            }
            let loader = Loader(parentActivity: loaderActivity,
                                externaFunctionImplementations: externaFunctionImplementations,
                                objectFile: arm64Binary.binary,
                                objectFileReader: arm64Binary.reader,
                                loadedLibrariesStorage: loadedLibrariesStorage)
            let _ = try loader.loadIntoMemory()
        }
        
        // suppose all libraries are loaded
        return binary
    }
    
    func resolveExternals(loadedBinary: LoadedBinary, visited: inout [String: Bool]) throws {
        if visited[loadedBinary.name] == true {
            return
        }
        
        for dependency in loadedBinary.objectFile.getLcLoadDylibCommands() {
            guard let dependencyUrl = URL(string: dependency.filePathString) else {
                throw Error.unableToParseDependency
            }
            
            let dependencyName = dependencyUrl.lastPathComponent
            loaderActivity.info("binary \(loadedBinary.name) is depends on \(dependencyName)")
            
            guard let loadedDependency = loadedLibrariesStorage.loadedLibraries[dependencyName] else {
                throw Error.unableToParseDependency
            }
            
            try resolveExternals(loadedBinary: loadedDependency, visited: &visited)
        }
        
        // At this point all dependencies are resolved and we can resolve `loadedBinary`
        // resolve fixups
        try resolveFixups(in: loadedBinary, fixups: loadedBinary.objectFile.getLcChainedFixupsCommands())
        // resolve symtab / dysymtab symbols (UNDEFINED only)
        visited[loadedBinary.name] = true
    }
    
    // Only load to ram, no external resolving
    private func loadMachoBinary() throws -> LoadedBinary
    {
        let allLoadSegmentCommands = objectFile.getLoadSegmentCommands()
        
        let totalVmSize = allLoadSegmentCommands
            .filter({ !$0.segname.contains("__PAGEZERO") })
            .reduce(0, { $0 + $1.vmsize })
        
        // allocate vm
        let pageSize = sysconf(_SC_PAGESIZE)
        let alignedSize = (Int(totalVmSize) + pageSize - 1) & ~(pageSize - 1)
        let virtualMemoryBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: alignedSize, alignment: pageSize)
        memset(virtualMemoryBuffer.baseAddress!, 0x0, Int(alignedSize))
        // FIXME: Remove dealloc
        let virtualMemory = try RamEditor(parentActivity: loaderActivity, existingBuffer: virtualMemoryBuffer, deallocBufferOnDeinit: false)
        
        let sections = try objectFile.getLoadSegmentCommands()
            .flatMap { try executeLoadSegmentCommand(parentActivity: loaderActivity, command: $0, within: objectFile, fileReader: objectFileReader, vm: virtualMemory) }
        
        if objectFile.isExecutable {
            guard let lcMainCommand = objectFile.commands.first(where: { $0.type == CommandHeader.CommandType.LC_MAIN.rawValue }) as? LcMain else {
                throw Error.unableToLocateLcMainCommand
            }
            
            let entrypoint = LoadedExecutable.EntryPoint(address: Int(bitPattern: virtualMemory.baseAddress) + Int(lcMainCommand.entryOffset))
            return LoadedExecutable(name: objectFile.name, 
                                    ram: try virtualMemory.baseReader(),
                                    entrypoint: entrypoint,
                                    symbolsTable: SymbolsTable(symbols: symbolsTable),
                                    objectFile: objectFile,
                                    sections: sections)
        }
        else {
            return LoadedLibrary(name: objectFile.name, 
                                 ram: try virtualMemory.baseReader(),
                                 symbolsTable: SymbolsTable(symbols: symbolsTable),
                                 objectFile: objectFile,
                                 sections: sections)
        }
    }
    
    // Returns all Segments (including __PAGEZERO)
    private func executeLoadSegmentCommand(parentActivity: Activity, command: LcSegment64, within binary: MachObjectFile, fileReader: MemoryEditor, vm: RamEditor) throws -> [RamEditor] {
        parentActivity.verbose("Loading segment: \(command.segname)")
        var sections = [RamEditor]()
        if command.segname == "__PAGEZERO" {
            parentActivity.verbose("Do nothing for this segment")
            for _ in command.sections {
                sections.append(try RamEditor(parentActivity: parentActivity, data: Data()))
            }
            return sections
        }
        
        let segmentStartAddress = binary.isExecutable ? command.vmaddr - 0x100000000 : command.vmaddr
        let segmentEditor = try vm.baseReader().child(startingAt: segmentStartAddress, size: command.vmsize)
        for section in command.sections {
            parentActivity.verbose(
                "Loading section: \(section.sectname). Offset in file: \(section.offset.hexRepresentation) Size: \(section.size)"
            )
            try fileReader.setVirtualOffset(section.offset)
            let sectionContent = try fileReader.readNext(section.size)
            
            let sectionAddressInRam = binary.isExecutable ? section.addr - 0x100000000 : section.addr
            let sectionEditor = try segmentEditor.baseReader().child(startingAt: sectionAddressInRam - segmentEditor.realOffset, size: section.size)
            try sectionEditor.write(data: sectionContent)
            
            sections.append(try sectionEditor.baseReader())
        }
        return sections
    }
    
    private func resolveFixups(in loadedBinary: LoadedBinary, fixups: [LcDyldChainedFixups]) throws {
        loaderActivity.info("Resolving fixups for binary: \(loadedBinary.name)")
        let baseVmAddress = Int(bitPattern: loadedBinary.ram.baseAddress)
        for fixup in fixups {
            loaderActivity.debug("Fixing: \(fixup)")
            for bind in fixup.infoForLinker.binds {
                if let functionPointer = externaFunctionImplementations[bind.symbolName] {
                    loaderActivity.verbose("Binding symbol \(bind.symbolName) in \(loadedBinary.name) to resolved address \(functionPointer.hexRepresentation) (from externaFunctionImplementations)")
                    try loadedBinary.ram.write(integer: functionPointer, atOffset: bind.offsetInSegment)
                }
                else if let (lib, address) = loadedLibrariesStorage.lookupSymbol(bind.symbolName) {
                    loaderActivity.verbose("Binding symbol \(bind.symbolName) in \(loadedBinary.name) to resolved address \(address.hexRepresentation) (from \(lib.name))")
                    try loadedBinary.ram.write(integer: address, atOffset: bind.offsetInSegment)
                }
                else {
                    loaderActivity.warning("Not found address for symbol: \(bind.symbolName)")
                }
            }
            for rebase in fixup.infoForLinker.rebases {
                let newAddress = UInt64(baseVmAddress) + rebase.addressToRebase
                loaderActivity.verbose("Rebasing symbol: \(rebase.offsetInSegment.hexRepresentation) to \(newAddress.hexRepresentation) in \(loadedBinary.name)")
                try loadedBinary.ram.write(integer: newAddress, atOffset: rebase.offsetInSegment)
            }
        }
    }
    
}

extension MachObjectFile {
    
    func getLcSymTabCommands() -> [LCSymTab] {
        commands.compactMap { $0 as? LCSymTab }
    }
    
    func getLcChainedFixupsCommands() -> [LcDyldChainedFixups] {
        commands.compactMap { $0 as? LcDyldChainedFixups }
    }
    
    func getLoadSegmentCommands() -> [LcSegment64] {
        commands.compactMap { $0 as? LcSegment64 }
    }
    
    func getLcLoadDylibCommands() -> [LinkLibraryCommand] {
        commands.compactMap { $0 as? LinkLibraryCommand }
    }
    
    func getLcMainCommand() -> LcMain? {
        commands.compactMap { $0 as? LcMain }.first
    }
    
    func getLcLoadDylibReexportCommands() -> [LinkLibraryCommand] {
        return getLcLoadDylibCommands().filter { $0.additional.isReexport }
    }
    
}
