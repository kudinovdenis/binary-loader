struct VersionNibble {
    
    let srtingValue: String
    let raw: UInt32
    
    init(raw: UInt32) {
        self.raw = raw
        // xxxx.yy.zz
        self.srtingValue = "\(raw >> 16 & 0xffff).\(raw >> 8 & 0xff).\(raw & 0xff)"
    }
    
}
