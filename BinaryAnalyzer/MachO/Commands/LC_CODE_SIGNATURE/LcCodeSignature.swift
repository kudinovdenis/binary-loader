struct LcCodeSignature: LinkEditCommand {
    let type: UInt32
    let size: UInt32
    let dataOffset: UInt32
    let dataSize: UInt32
}
