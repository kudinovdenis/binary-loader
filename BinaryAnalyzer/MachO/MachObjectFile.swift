public struct MachObjectFile {
    public let header: MachOHeader
    public let commands: [Command]
    public let name: String
}

public extension MachObjectFile {
    
    var isExecutable: Bool { header.fileType == 0x2 }
    var isSharedLibrary: Bool { header.fileType == 0x6 }
    
}

public extension MachObjectFile {
    
    var isArm64: Bool { header.cpuTypeHumanReadable == .arm && header.cpuSubType == 0x0 }
    
}
