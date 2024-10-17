import KLActivityLogger

open class MemoryEditorImpl: MemoryEditor {
    
    enum Error: Swift.Error {
        case notEnoughBytesLeft
        case noDataHasBeenRead
        case invalidStringData
        case notImplemented
        case readingOffMemory
        case writingOffMemory
    }
    
    
    public var size: MemorySize {
        virtualSize
    }
    public let totalSize: MemorySize
    public let virtualSize: MemorySize
    public let virtualStart: MemorySize
    public var virtualOffset: UInt64
    
    public var realOffset: UInt64 {
        virtualStart + virtualOffset
    }
    
    private let readerActivity: Activity
    
    // base offset -- minimal offset for this reader (useful for child creation)
    public init(readyToUseActivity: Activity, totalSize: MemorySize, virtualSize: MemorySize? = nil, offset: any FixedWidthInteger = 0) throws {
        self.totalSize = totalSize
        
        virtualStart = UInt64(offset)
        let virtualSize = virtualSize ?? totalSize - UInt64(virtualStart)
        guard UInt64(virtualStart) + virtualSize <= totalSize else {
            throw Error.notEnoughBytesLeft
        }
        self.virtualSize = virtualSize
        self.virtualOffset = 0
        
        readerActivity = readyToUseActivity
        
        try setVirtualOffset(0)
    }

    public func advance(by numberOfBytes: any FixedWidthInteger) throws {
        readerActivity.debug("advancing by \(numberOfBytes)")
        guard virtualOffset + UInt64(numberOfBytes) <= virtualSize else {
            throw Error.notEnoughBytesLeft
        }
        try setVirtualOffset(virtualOffset + UInt64(numberOfBytes))
    }
    
    public func unwind(by numberOfBytes: any FixedWidthInteger) throws {
        readerActivity.debug("unwinding by \(numberOfBytes)")
        guard UInt64(numberOfBytes) <= virtualOffset else {
            throw Error.readingOffMemory
        }
        try setVirtualOffset(virtualOffset - UInt64(numberOfBytes))
    }
    
    public func readNext(_ numberOfBytes: any FixedWidthInteger) throws -> Data {
        readerActivity.debug("reading next \(numberOfBytes)b.")
        guard virtualOffset + UInt64(numberOfBytes) <= virtualSize else {
            throw Error.notEnoughBytesLeft
        }
        
        guard UInt64(numberOfBytes) <= Int.max else {
            // TODO: split into chunks Int.max
            readerActivity.error("numberOfBytes if too big (> Int.max)")
            throw Error.noDataHasBeenRead
        }
        
        let readData = try actualReadData(numberOfBytes: numberOfBytes)
        
        try setVirtualOffset(virtualOffset + UInt64(numberOfBytes))
        return readData
    }
    
    public func readString(size: any FixedWidthInteger) throws -> String {
        readerActivity.debug("reading next string \(size)b.")
        let data = try readNext(size)
        
        guard let result = String(data: data, encoding: .utf8) else {
            throw Error.invalidStringData
        }
        
        return result.trimmingCharacters(in: ["\0"])
    }
    
    public func readNext<T: FixedWidthInteger>() throws -> T {
        let bytesSize = UInt64(T.bitWidth / 8)
        readerActivity.debug("reading next \(T.self) (\(bytesSize)b.)")
        let data = try actualReadDataForInteger(numberOfBytes: bytesSize)
        return T(littleEndian: data.withUnsafeBytes({ $0.load(as: T.self) }))
    }
    
    public func setVirtualOffset(_ newOffset: any FixedWidthInteger) throws {
        readerActivity.debug("setting current offset to \(newOffset.hexRepresentation) (Real: \(realOffset.hexRepresentation))")
        if UInt64(newOffset) > virtualSize {
            throw Error.notEnoughBytesLeft
        }
        self.virtualOffset = UInt64(newOffset)
    }
    
    public func write(data: Data, atOffset: any FixedWidthInteger) throws {
        guard UInt64(atOffset) + UInt64(data.count) <= virtualSize else {
            throw Error.writingOffMemory
        }
        let previousOffset = virtualOffset
        try setVirtualOffset(atOffset)
        try actualWriteData(data: data)
        try setVirtualOffset(previousOffset)
    }
    
    public func write(data: Data) throws {
        guard virtualOffset + UInt64(data.count) <= virtualSize else {
            throw Error.writingOffMemory
        }
        try actualWriteData(data: data)
        try setVirtualOffset(virtualOffset + UInt64(data.count))
    }
    
    public func write(integer: any FixedWidthInteger) throws {
        let dataToWrite = try actualDataForInteger(integer: integer)
        try write(data: dataToWrite)
    }
    
    public func write<T: FixedWidthInteger>(integer: T, atOffset: any FixedWidthInteger) throws {
        let dataToWrite = try actualDataForInteger(integer: integer)
        try write(data: dataToWrite, atOffset: atOffset)
    }
    
    public func hexRepresentation() throws -> String {
        try hexRepresentation(fromOffset: 0, toOffset: virtualSize, alignment: 16)
    }
    
    public func hexRepresentation(ofNext nBytes: any FixedWidthInteger, alignment: any FixedWidthInteger) throws -> String {
        try hexRepresentation(fromOffset: virtualOffset, toOffset: virtualOffset + UInt64(nBytes), alignment: alignment)
    }
    
    public func hexRepresentation(fromOffset: any FixedWidthInteger, toOffset: any FixedWidthInteger, alignment: any FixedWidthInteger) throws -> String {
        guard UInt64(toOffset) <= virtualSize else {
            throw Error.readingOffMemory
        }
        
        let nBytes = UInt64(toOffset) - UInt64(fromOffset)
        let hexReader = try baseReader().child(startingAt: fromOffset, size: nBytes)
        
        var result = "\n"
        result += hexRepresentationColumnNames().joined(separator: "\t")
        result += "\n"
        
        let startOffset = UInt64(fromOffset)
        var currentOffset: UInt64 = .max
        
        let startRealOffset = hexReader.realOffset
        var currentRealOffset: UInt64 = .max
        
        let bytes = try hexReader.readNext(nBytes)
        
        var bytesInLine = Data()
        for (i, byte) in bytes.enumerated() {
            if currentOffset == .max {
                currentOffset = startOffset + UInt64(i)
                currentRealOffset = startRealOffset + UInt64(i)
            }
            
            bytesInLine.append(byte)
            
            if bytesInLine.count == alignment || i == nBytes - 1 {
                result += hexRepresentationComponentsForBytes(realOffset: currentRealOffset,
                                                              relativeOffset: currentOffset,
                                                              bytes: bytesInLine).joined(separator: "\t")
                result += "\n"
                
                bytesInLine = Data()
                currentOffset = .max
            }
        }
        
        return result
    }
    
    public func child(startingAt relativeOffset: any FixedWidthInteger) throws -> Self {
        let realOffset = self.realOffset + UInt64(relativeOffset)
        guard realOffset <= totalSize else {
            throw Error.readingOffMemory
        }
        
        return try child(startingAt: relativeOffset, size: totalSize - realOffset)
    }
    
    public func child(startingAt relativeOffset: any FixedWidthInteger, size: MemorySize) throws -> Self {
        let realOffset = self.realOffset + UInt64(relativeOffset)
        guard realOffset + size <= totalSize else {
            throw Error.readingOffMemory
        }
        
        return try instanciate(realOffset: realOffset, size: size)
    }
    
    public func baseReader() throws -> Self {
        return try instanciate(realOffset: virtualStart, size: virtualSize)
    }
    
    // Implementations to override
    
    open func hexRepresentationColumnNames() -> [String] {
        return [
            "RelativeOffset",
            "RealOffset",
            "Value",
            "Symbols"
        ]
    }
    
    open func hexRepresentationComponentsForBytes(realOffset: UInt64, relativeOffset: UInt64, bytes: Data) -> [String] {
        return [
            relativeOffset.hexRepresentation,
            realOffset.hexRepresentation,
            bytes.reduce(into: "", { $0.append("\($1.hexRepresentationForByteNo0x) ") }),
            bytes.reduce(into: "", { $0.append("\(String.uint8ToPrintableString($1)) ") })
        ]
    }
    
    open func actualReadData(numberOfBytes: any FixedWidthInteger) throws -> Data {
        throw Error.notImplemented
    }
    
    open func actualReadDataForInteger(numberOfBytes: any FixedWidthInteger) throws -> Data {
        throw Error.notImplemented
    }
    
    open func actualWriteData(data: Data) throws {
        throw Error.notImplemented
    }
    
    open func actualDataForInteger<T: FixedWidthInteger>(integer: T) throws -> Data {
        throw Error.notImplemented
    }
    
    open func instanciate(realOffset: UInt64, size: MemorySize) throws -> Self {
        throw Error.notImplemented
    }
    
}

extension String {
    
    static func uint8ToPrintableString(_ value: UInt8) -> String {
        if value >= 32 && value <= 126 {
            return String(UnicodeScalar(value))
        } else {
            return "."
        }
    }
    
}
