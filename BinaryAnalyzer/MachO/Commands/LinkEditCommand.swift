protocol LinkEditCommand: Command {
    var dataOffset: UInt32 { get }
    var dataSize: UInt32 { get }
}
