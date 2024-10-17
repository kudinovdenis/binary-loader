public struct MachoFatBinary {
    
    public struct Header {
        
        public let magic: UInt32
        public let nArchitectures: UInt32
        
    }
    
    public struct SingleBinaryInfo {
        
        public let cputype: UInt32    // CPU type (e.g., CPU_TYPE_X86_64, CPU_TYPE_ARM64)
        public let cpusubtype: UInt32 // CPU subtype (e.g., CPU_SUBTYPE_ARM64_ALL)
        public let offset: UInt32     // Offset to the Mach-O binary for this architecture
        public let size: UInt32      // Size of the Mach-O binary for this architecture
        public let align: UInt32      // Alignment of the binary (as a power of 2)
        
    }
    
}
