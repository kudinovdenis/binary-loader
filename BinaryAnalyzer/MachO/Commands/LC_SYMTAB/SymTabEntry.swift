// https://opensource.apple.com/source/xnu/xnu-1228.0.2/EXTERNAL_HEADERS/mach-o/nlist.h.auto.html
public struct SymTabEntry {
    public let indexIntoStringTable: UInt32 /* index into the string table */
    public let typeFlag: UInt8 /* type flag, see description */
    public let sectionNumber: UInt8 /* section number or NO_SECT */
    public let desc: UInt16 /* see <mach-o/stab.h> */
    public let valueOfSymbol: UInt64 /* value of this symbol (or stab offset) */
    //
    public let additional: Additional
    
    public var toInfoForLinker: LCSymTab.InfoForLinker.SymbolType {
        if additional.flags.isPublicExternal && typeFlag == 0x1 {
            return .undefined(symbolName: additional.symbolName, offsetToWriteAddress: valueOfSymbol)
        }
        if additional.flags.isUndefined {
            return .undefined(symbolName: additional.symbolName, offsetToWriteAddress: valueOfSymbol)
        }
        if additional.flags.isPublicExternal {
            return .publicExternal(symbolName: additional.symbolName, addressRelativeToStartOfSection: valueOfSymbol, sectionNumber: Int(sectionNumber))
        }
        if additional.flags.isPrivateExternal {
            return .publicExternal(symbolName: additional.symbolName, addressRelativeToStartOfSection: valueOfSymbol, sectionNumber: Int(sectionNumber))
        }
        if additional.flags.isDebugStabSymbol {
            return .debugStab(symbolName: additional.symbolName)
        }
        if additional.flags.isAbsolute {
            return .absolute(symbolName: additional.symbolName, address: valueOfSymbol)
        }
        fatalError("Unsupported type of entry")
    }
}

extension SymTabEntry {
    
    public struct Additional: CustomStringConvertible {
        
        public struct Flags: CustomStringConvertible {
            
            private let rawValue: UInt8
            private let n_stab: UInt8
            private let n_pext: UInt8
            private let n_type: UInt8
            private let n_ext: UInt8
            
            static let N_UNDF = 0x0        /* undefined, n_sect == NO_SECT */
            static let N_ABS = 0x2        /* absolute, n_sect == NO_SECT */
            static let N_SECT = 0xe        /* defined in section number n_sect */
            static let N_PBUD = 0xc        /* prebound undefined (defined in a dylib) */
            static let N_INDR = 0xa        /* indirect */
            
            var isUndefined: Bool { n_type & UInt8(Flags.N_UNDF) != 0 }
            var isAbsolute: Bool { n_type & UInt8(Flags.N_ABS) != 0 }
            var isDefinedInSomeSection: Bool { n_type & UInt8(Flags.N_SECT) != 0 }
            var isDefinedInDyLib: Bool { n_type & UInt8(Flags.N_PBUD) != 0 }
            var isIndirect: Bool { n_type & UInt8(Flags.N_INDR) != 0 }
            
            var isPublicExternal: Bool { n_ext != 0 }
            var isPrivateExternal: Bool { n_pext != 0 }
            var isDebugStabSymbol: Bool { n_stab != 0 }
            
            public init(raw: UInt8) {
                rawValue = raw
                n_stab = rawValue & 0xe0
                n_pext = rawValue & 0x10
                n_type = rawValue & 0x0e
                n_ext = rawValue & 0x01
            }
            
            public var description: String {
                """
                N_STAB: \(n_stab.hexRepresentation)
                N_PEXT: \(n_pext.hexRepresentation)
                N_TYPE: \(n_type.hexRepresentation)
                    isUndefined: \(isUndefined)
                    isAbsolute: \(isAbsolute)
                    isDefinedInSomeSection: \(isDefinedInSomeSection)
                    isDefinedInDyLib: \(isDefinedInDyLib)
                    isIndirect: \(isIndirect)
                N_EXT: \(n_ext.hexRepresentation)
                """
            }
            
        }
        
        public let symbolName: String
        public let flags: Flags
        
        init(symbolName: String, typeFlag: UInt8) {
            self.symbolName = symbolName
            flags = Flags(raw: typeFlag)
        }
        
        public var description: String {
            """
            Symbol name: \(symbolName)
            \(flags)
            """
        }
        
        func location(_ entry: SymTabEntry) -> String {
            var location = ""
            if flags.isPrivateExternal {
                location += "Private External;"
            }
            if flags.isPublicExternal {
                location += "Public External;"
            }
            if flags.isDebugStabSymbol {
                location += "Stab Debug;"
            }
            if flags.isUndefined {
                location += "Undefined(must be defined in some shared lib);"
            }
            if flags.isAbsolute {
                location += "Absolute (\(entry.valueOfSymbol.hexRepresentation));"
            }
            if flags.isDefinedInSomeSection {
                location += "Defined in section #\(entry.sectionNumber);"
            }
            if flags.isDefinedInDyLib {
                location += "Prebind. Assume will never see this...;"
            }
            if flags.isIndirect {
                location += "Indirect. Same as symbol at Index in string table \(entry.valueOfSymbol);"
            }
            return location
        }

    }
    
}

extension SymTabEntry: CustomStringConvertible {
    
    public var description: String {
        """
        indexIntoStringTable: \(indexIntoStringTable)
        typeFlag: \(typeFlag.binRepresentation)
        sectionNumber: \(sectionNumber)
        desc: \(desc)
        valueOfSymbol: \(valueOfSymbol.hexRepresentation)
        Additional: \(additional)
        Location: \(additional.location(self))
        """
    }
    
}
