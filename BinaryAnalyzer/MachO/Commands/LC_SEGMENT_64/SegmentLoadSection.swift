extension LcSegment64 {
    
    /**
     struct section_64 { /* for 64-bit architectures */
         char        sectname[16];    /* name of this section */
         char        segname[16];    /* segment this section goes in */
         uint64_t    addr;        /* memory address of this section */
         uint64_t    size;        /* size in bytes of this section */
         uint32_t    offset;        /* file offset of this section */
         uint32_t    align;        /* section alignment (power of 2) */
         uint32_t    reloff;        /* file offset of relocation entries */
         uint32_t    nreloc;        /* number of relocation entries */
         uint32_t    flags;        /* flags (section type and attributes)*/
         uint32_t    reserved1;    /* reserved (for offset or index) */
         uint32_t    reserved2;    /* reserved (for count or sizeof) */
         uint32_t    reserved3;    /* reserved */
     };
     */
    
    public struct Section: CustomStringConvertible  {
        public let sectname: String /* name of this section */
        public let segname: String /* segment this section goes in */
        public let addr: UInt64 /* memory address of this section */
        public let size: UInt64 /* size in bytes of this section */
        public let offset: UInt32 /* file offset of this section */
        public let align: UInt32 /* section alignment (power of 2) */
        public let relocationsFileOffset: UInt32 /* file offset of relocation entries */
        public let numberOfRelocations: UInt32 /* number of relocation entries */
        public let flag: UInt32
        public let reserved1: UInt32
        public let reserved2: UInt32
        public let reserved3: UInt32
        
        public var description: String {
            return """
            Section name: \(sectname)
            Segment name: \(segname)
            Section address: \(addr.hexRepresentation)
            Section size: \(size)
            Section size offset: \(offset.hexRepresentation)
            Alignment: \(align)
            Relocations file offset: \(relocationsFileOffset.hexRepresentation)
            Number of relocations: \(numberOfRelocations)
            Flag: \(flag.binRepresentation)
            Reserved1: \(reserved1)
            Reserved2: \(reserved2)
            Reserved3: \(reserved3)
            """
        }
    }
    
}
