import KLActivityLogger

public typealias MemorySize = UInt64

public protocol MemoryEditor {
    
    var virtualOffset: UInt64 { get }
    var realOffset: UInt64 { get }
    var size: MemorySize { get }
    
    // Offset
    func setVirtualOffset(_ newOffset: any FixedWidthInteger) throws
    func advance(by numberOfBytes: any FixedWidthInteger) throws
    func unwind(by numberOfBytes: any FixedWidthInteger) throws
    
    // Read
    func readNext(_ numberOfBytes: any FixedWidthInteger) throws -> Data
    func readString(size: any FixedWidthInteger) throws -> String
    func readString(terminator: UInt8) throws -> String
    func readNextNullTerminatedString() throws -> String
    func readNext<T: FixedWidthInteger>() throws -> T
    
    // Write
    func write(data: Data) throws
    func write(data: Data, atOffset: any FixedWidthInteger) throws
    func write(integer: any FixedWidthInteger) throws
    func write<T: FixedWidthInteger>(integer: T, atOffset: any FixedWidthInteger) throws
    
    // Convenience
    func hexRepresentation() throws -> String
    func hexRepresentation(ofNext nBytes: any FixedWidthInteger, alignment: any FixedWidthInteger) throws -> String
    
    func child(startingAt offset: any FixedWidthInteger, size: UInt64) throws -> Self
    func child(startingAt offset: any FixedWidthInteger) throws -> Self
    func baseReader() throws -> Self
    
}

extension MemoryEditor {
    
    public func readString(terminator: UInt8) throws -> String {
        var result = [UInt8]()
        while true {
            let nextChar: UInt8 = try readNext()
            result.append(nextChar)
            if nextChar == terminator {
                break
            }
        }
        return String.init(cString: result)
    }
    
    public func readNextNullTerminatedString() throws -> String {
        return try readString(terminator: Character("\0").asciiValue!)
    }
    
}
