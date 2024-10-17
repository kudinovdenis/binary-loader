public protocol Command {
    var type: UInt32 { get }
    var size: UInt32 { get }
}

public struct CommandHeader {
    
    static let sizeInBytes: UInt32 = 4 + 4
    
    public enum CommandType: UInt32, RawRepresentable {
        // https://opensource.apple.com/source/xnu/xnu-4903.221.2/EXTERNAL_HEADERS/mach-o/loader.h.auto.html
        case LC_SEGMENT_64 = 0x19
        case LC_LOAD_DYLIB = 0xC
        case LC_ID_DYLIB = 0xD
        case LC_LOAD_WEAK_DYLIB = 0x80000018 // 0x80000000 | 0x18
        case LC_BUILD_VERSION = 0x32
        case LC_DYLD_EXPORTS_TRIE = 0x80000033 // https://opensource.apple.com/source/xnu/xnu-7195.81.3/EXTERNAL_HEADERS/mach-o/fixup-chains.h.auto.html
        case LC_DYLD_CHAINED_FIXUPS = 0x80000034 // https://opensource.apple.com/source/xnu/xnu-7195.81.3/EXTERNAL_HEADERS/mach-o/fixup-chains.h.auto.html
        case LC_SYMTAB = 0x2 /* link-edit stab symbol table info */
        case LC_DYSYMTAB = 0xb /* dynamic link-edit symbol table info */
        case LC_LOAD_DYLINKER = 0xE /* load a dynamic linker */
        case LC_UUID = 0x1b /* the uuid */
        case LC_SOURCE_VERSION = 0x2A /* source version used to build binary */
        case LC_MAIN = 0x80000028
        case LC_ENCRYPTION_INFO_64 = 0x2C /* 64-bit encrypted segment information */
        case LC_RPATH = 0x8000001c /* runpath additions */
        case LC_FUNCTION_STARTS = 0x26 /* compressed table of function start addresses */
        case LC_DATA_IN_CODE = 0x29 /* table of non-instructions in __text */
        case LC_CODE_SIGNATURE = 0x1d /* local of code signature */
        case LC_REEXPORT_DYLIB = 0x8000001f /* load and re-export dylib */
        case LC_SEGMENT_SPLIT_INFO = 0x1e
    }
    
    let type: UInt32
    let size: UInt32
}

struct SkipCommand: Command {
    let type: UInt32
    let size: UInt32
}
