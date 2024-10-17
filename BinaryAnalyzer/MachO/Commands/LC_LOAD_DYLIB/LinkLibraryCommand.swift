public struct LinkLibraryCommand: Command {
    
    public struct Additional {
        public let dylibName: String
        public let isReexport: Bool
    }
    
    public enum LinkType {
        case fullPath
        case relativePath
        case `weak`
    }
    
    public let type: UInt32
    public let size: UInt32
    public let linkType: LinkType
    public let stringOffset: UInt32
    public let timeDateStamp: UInt32
    public let currentVersion: UInt32
    public let compatibleVersion: UInt32
    public let filePathString: String
    public let additional: Additional
    
}

extension LinkLibraryCommand.LinkType {
    
    public init(commandType: CommandHeader.CommandType) {
        switch commandType {
        case .LC_LOAD_DYLIB: self = .fullPath
        case .LC_ID_DYLIB: self = .relativePath
        case .LC_LOAD_WEAK_DYLIB: self = .weak
        default: self = .weak
        }
    }
    
}
