public extension FixedWidthInteger {
    var hexRepresentation: String {
        return "0x\(String(self, radix: 16))"
    }
    
    var hexRepresentationForByteNo0x: String {
        var representation = String(self, radix: 16)
        if representation.count < 2 {
            representation = "0" + representation
        }
        return "\(representation)"
    }
    
    var hexRepresentationNo0x: String {
        return String(self, radix: 16)
    }
    
    var binRepresentation: String {
        return "b\(String(self, radix: 2))"
    }
}

public extension FixedWidthInteger {
    
    var sizeInBytes: UInt8 {
        return numericCast(Self.bitWidth / 8)
    }
    
}

public extension FixedWidthInteger {
    
    static var byteWidth: UInt8 {
        return UInt8(bitWidth / 8)
    }
    
}
