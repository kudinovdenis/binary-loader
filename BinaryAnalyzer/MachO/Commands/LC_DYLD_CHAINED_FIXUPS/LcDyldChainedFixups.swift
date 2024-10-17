public final class LcDyldChainedFixups: Command {
    
    public struct InfoForLinker {
        // since this command is large and complicated,
        // output will be minimal, but enough for linker
        
        public struct Rebase {
            public  let segmentIndex: UInt32 // Index in LC_LOAD_SEGMENT commands
            public  let offsetInSegment: UInt64 // Relative index (Linker MUST write here resolved address)
            public  let addressToRebase: UInt64 // This address should be adjusted due to ASLR
        }
        
        public struct Bind {
            public let segmentIndex: UInt32 // Index in LC_LOAD_SEGMENT commands
            public  let offsetInSegment: UInt64 // Relative index (Linker MUST write here resolved address)
            public let libraryIndexContainingSymbol: UInt32 // This is index in array of LC_LOAD_DYLIB commands. Note: 0 means SELF binary. So need to subtract 1 from this index
            public  let symbolName: String // Name of symbol to be resolved in some external lib
        }
        
        public let rebases: [Rebase]
        public let binds: [Bind]
    }
    
    public let type: UInt32
    public let size: UInt32
    
    public let infoForLinker: InfoForLinker
    
    init(type: UInt32, size: UInt32, infoForLinker: InfoForLinker) {
        self.type = type
        self.size = size
        self.infoForLinker = infoForLinker
    }
    
}
