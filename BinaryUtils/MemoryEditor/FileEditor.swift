import KLActivityLogger

public final class FileEditor: MemoryEditorImpl {
    
    public enum Endian {
        case big
        case little
    }
    
    enum Error: Swift.Error {
        case unableToReadFileAttributes
        case noDataHasBeenRead
        case readingOffFile
        case invalidStringData
        case notImplemented
    }
    
    private let fileHandle: FileHandle
    private let fileUrl: URL
    private let readerActivity: Activity
    private let endian: Endian
    
    // base offset -- minimal offset for this reader (useful for child creation)
    public init(parentActivity: Activity, 
                fileUrl: URL,
                endian: Endian = .little,
                offset: any FixedWidthInteger = 0,
                virtualSize: MemorySize? = nil) throws
    {
        readerActivity = parentActivity.childActivity(named: "File:\(fileUrl.lastPathComponent)|Offset:\(offset.hexRepresentation)")
        readerActivity.start()
        
        self.endian = endian
        do {
            self.fileUrl = fileUrl
            fileHandle = try FileHandle(forReadingFrom: fileUrl)
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
            guard let fileSize = fileAttributes[.size] as? UInt64 else {
                throw Error.unableToReadFileAttributes
            }
            
            let totalSize = MemorySize(fileSize)
            try super.init(readyToUseActivity: readerActivity, totalSize: totalSize, virtualSize: virtualSize, offset: offset)
        }
        catch {
            readerActivity.failure("Error opening file: \(error)")
            readerActivity.markAsReadyToFinish()
            throw error
        }
    }
    
    deinit {
        readerActivity.markAsReadyToFinish()
    }
    
    // Read
    
    public override func actualReadData(numberOfBytes: any FixedWidthInteger) throws -> Data {
        guard UInt64(numberOfBytes) > 0 else {
            return Data()
        }
        try fileHandle.seek(toOffset: realOffset)
        guard let readData = try fileHandle.read(upToCount: Int(numberOfBytes)) else {
            throw Error.noDataHasBeenRead
        }
        return readData
    }
    
    public override func actualReadDataForInteger(numberOfBytes: any FixedWidthInteger) throws -> Data {
        var data = try readNext(numberOfBytes)
        if endian == .big {
            data.reverse()
        }
        return data
    }
    
    // Write
    
    public override func actualDataForInteger<T: FixedWidthInteger>(integer: T) throws -> Data {
        var mutableData = integer
        var data = Data(bytes: &mutableData, count: Int(mutableData.sizeInBytes))
        if endian == .big {
            data.reverse()
        }
        return data
    }
    
    public override func actualWriteData(data: Data) throws {
        try fileHandle.seek(toOffset: realOffset)
        try fileHandle.write(contentsOf: data)
    }
    
    // Child
    
    public override func instanciate(realOffset: UInt64, size: MemorySize) throws -> Self {
        try Self(parentActivity: readerActivity,
                 fileUrl: fileUrl,
                 endian: .little,
                 offset: realOffset,
                 virtualSize: size)
    }
    
}
