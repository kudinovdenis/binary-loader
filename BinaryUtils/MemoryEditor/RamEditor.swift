import KLActivityLogger

public final class RamEditor: MemoryEditorImpl {
    
    enum Error: Swift.Error {
        case unableToCreateBuffer
        case brokenBuffer
        case bufferIsTooSmall
    }
    
    public var baseAddress: UnsafeMutableRawPointer {
        baseBufferPointer.baseAddress!
    }

    private let editorActivity: Activity
    private let baseBufferPointer: UnsafeMutableRawBufferPointer
    private let deallocBufferOnDeinit: Bool
    
    public init(parentActivity: ChildActivityFactory, 
                existingBuffer: UnsafeMutableRawBufferPointer,
                deallocBufferOnDeinit: Bool,
                offset: any FixedWidthInteger = 0,
                virtualSize: MemorySize? = nil) throws
    {
        editorActivity = parentActivity.childActivity(named: "RAM|\(Int(bitPattern: existingBuffer.baseAddress?.advanced(by: Int(offset))).hexRepresentation)")
        editorActivity.start()
        self.baseBufferPointer = existingBuffer
        self.deallocBufferOnDeinit = deallocBufferOnDeinit
        
        let totalSize = MemorySize(existingBuffer.count)
        try super.init(readyToUseActivity: editorActivity, totalSize: totalSize, virtualSize: virtualSize, offset: offset)
    }
    
    public convenience init(parentActivity: ChildActivityFactory, pointer: UnsafeMutableRawPointer, size: UInt64, deallocBufferOnDeinit: Bool) throws {
        let buffer = UnsafeMutableRawBufferPointer(start: pointer, count: Int(size))
        try self.init(parentActivity: parentActivity, existingBuffer: buffer, deallocBufferOnDeinit: deallocBufferOnDeinit)
    }
    
    public convenience init(parentActivity: ChildActivityFactory, address: Int, size: UInt64, deallocBufferOnDeinit: Bool = true) throws {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else {
            throw Error.unableToCreateBuffer
        }
        try self.init(parentActivity: parentActivity, pointer: pointer, size: size, deallocBufferOnDeinit: true)
    }
    
    public convenience init(parentActivity: ChildActivityFactory, data: Data, deallocBufferOnDeinit: Bool = true) throws {
        try self.init(parentActivity: parentActivity, size: UInt64(data.count), deallocBufferOnDeinit: deallocBufferOnDeinit)
        try write(data: data)
    }
    
    public convenience init(parentActivity: ChildActivityFactory, size: UInt64, deallocBufferOnDeinit: Bool = true) throws {
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size), alignment: 1)
        try self.init(parentActivity: parentActivity, existingBuffer: buffer, deallocBufferOnDeinit: deallocBufferOnDeinit)
    }
    
    deinit {
        editorActivity.markAsReadyToFinish()
        if deallocBufferOnDeinit {
            baseBufferPointer.deallocate()
        }
    }
    
    public override func actualReadData(numberOfBytes: any FixedWidthInteger) throws -> Data {
        guard let baseAddress = baseBufferPointer.baseAddress?.advanced(by: Int(realOffset)) else {
            throw Error.brokenBuffer
        }
        return Data(bytes: baseAddress, count: Int(numberOfBytes))
    }
    
    public override func actualReadDataForInteger(numberOfBytes: any FixedWidthInteger) throws -> Data {
        try readNext(numberOfBytes)
    }
    
    public override func actualDataForInteger<T: FixedWidthInteger>(integer: T) throws -> Data {
        var mutableData = integer
        return Data(bytes: &mutableData, count: Int(mutableData.sizeInBytes))
    }
    
    public override func actualWriteData(data: Data) throws {
        guard let offsetPtr = baseBufferPointer.baseAddress?.advanced(by: Int(realOffset)) else {
            throw Error.brokenBuffer
        }
        let mutableOffsetPtr = offsetPtr.assumingMemoryBound(to: UInt8.self)
        data.copyBytes(to: mutableOffsetPtr, count: data.count)
    }
    
    public override func instanciate(realOffset: UInt64, size: MemorySize) throws -> Self {
        return try Self(parentActivity: editorActivity,
                        existingBuffer: baseBufferPointer,
                        deallocBufferOnDeinit: false,
                        offset: realOffset,
                        virtualSize: size)
    }
    
    public override func hexRepresentationColumnNames() -> [String] {
        return ["Address"] + super.hexRepresentationColumnNames()
    }
    
    public override func hexRepresentationComponentsForBytes(realOffset: UInt64, relativeOffset: UInt64, bytes: Data) -> [String] {
        let address = Int(bitPattern: baseBufferPointer.baseAddress?.advanced(by: Int(realOffset))).hexRepresentation
        return [address] + super.hexRepresentationComponentsForBytes(realOffset: realOffset, relativeOffset: relativeOffset, bytes: bytes)
    }
    
}
