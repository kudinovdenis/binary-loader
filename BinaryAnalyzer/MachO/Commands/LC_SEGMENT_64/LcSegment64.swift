/*
 * The 64-bit segment load command indicates that a part of this file is to be
 * mapped into a 64-bit task's address space.  If the 64-bit segment has
 * sections then section_64 structures directly follow the 64-bit segment
 * command and their size is reflected in cmdsize.
 */

public struct LcSegment64: Command, CustomStringConvertible {
    
    public struct VMPermissions: OptionSet, CustomStringConvertible {
        public var rawValue: UInt32
        public static let R = VMPermissions(rawValue: 1 << 0)
        public static let W = VMPermissions(rawValue: 1 << 1)
        public static let X = VMPermissions(rawValue: 1 << 2)
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public var description: String {
            var result = ""
            if self.contains(.R) {
                result += "R"
            }
            if self.contains(.W) {
                result += "W"
            }
            if self.contains(.X) {
                result += "X"
            }
            return result
        }
    }
    
    public struct Flags: OptionSet, CustomStringConvertible {
        public var rawValue: UInt32
        static let forHighPartOfVmLowPartIsZero = Flags(rawValue: 1 << 0)
        static let alloctedByFixedVmLibrary = Flags(rawValue: 1 << 1)
        static let mayBeSafelyReplacedWithoutRelocation = Flags(rawValue: 1 << 2)
        static let segmentIsProtected = Flags(rawValue: 1 << 3)
        static let readOnlyAfterRelocationsAreAppliedIfNeeded = Flags(rawValue: 1 << 4)
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        public var description: String {
            var result = ""
            if self.contains(.forHighPartOfVmLowPartIsZero) {
                result += "forHighPartOfVmLowPartIsZero | "
            }
            if self.contains(.alloctedByFixedVmLibrary) {
                result += "alloctedByFixedVmLibrary |"
            }
            if self.contains(.mayBeSafelyReplacedWithoutRelocation) {
                result += "mayBeSafelyReplacedWithoutRelocation |"
            }
            if self.contains(.segmentIsProtected) {
                result += "segmentIsProtected |"
            }
            if self.contains(.readOnlyAfterRelocationsAreAppliedIfNeeded) {
                result += "readOnlyAfterRelocationsAreAppliedIfNeeded |"
            }
            return result
        }
    }
    
    public let type: UInt32 // LC_SEGMENT_64
    public let size: UInt32 /* includes sizeof section_64 structs */
    public let segname: String
    public let vmaddr: UInt64 /* memory address of this segment */
    public let vmsize: UInt64 /* memory size of this segment */
    public let fileoff: UInt64 /* file offset of this segment */
    public let filesize: UInt64 /* amount to map from the file */
    public let maxprot: VMPermissions /* maximum VM protection */
    public let initprot: VMPermissions /* initial VM protection */
    public let numberOfSections: UInt32 // read this number of sections after flag32
    public let flag32: Flags
    public let sections: [Section]
    
    public var description: String {
        return """
        Type: \(type.hexRepresentation)
        Command size: \(size)
        Segment name: \(segname)
        VmAddr: \(vmaddr.hexRepresentation)
        VmSize: \(vmsize)
        File offset: \(fileoff.hexRepresentation)
        Size (bytes from file offset): \(filesize)
        Maximum virtual memory protections: \(maxprot)
        Initial virtual memory protections: \(initprot)
        Number of sections: \(numberOfSections)
        Flag32: \(flag32)
        Sections: \(sections)
        """
    }
}
