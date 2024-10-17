struct LcDataInCode: LinkEditCommand {
    let type: UInt32
    let size: UInt32
    let dataOffset: UInt32 // see LC_DATA_IN_CODE in doc.
    let dataSize: UInt32
}
