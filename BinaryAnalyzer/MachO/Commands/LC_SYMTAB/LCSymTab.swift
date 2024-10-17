public struct LCSymTab: Command {
    public let type: UInt32
    public let size: UInt32
    public let symbolTableOffset: UInt32
    public let numberOfSymbolTableEntries: UInt32
    public let stringTableOffset: UInt32
    public let stringTableSize: UInt32
    public let symtabEntries: [SymTabEntry]
    
    public struct InfoForLinker {
        public enum SymbolType {
            case undefined(symbolName: String, offsetToWriteAddress: UInt64)
            case publicExternal(symbolName: String, addressRelativeToStartOfSection: UInt64, sectionNumber: Int)
            case privateExternal(symbolName: String, addressRelativeToStartOfSection: UInt64, sectionNumber: Int)
            case debugStab(symbolName: String)
            case absolute(symbolName: String, address: UInt64)
        }
        
        public let symbols: [SymbolType]
    }
    public let infoForLinker: InfoForLinker
}

extension LCSymTab: CustomStringConvertible {
    
    public var description: String {
        return """
        Size: \(size)
        Symbol table offset: \(symbolTableOffset.hexRepresentation)
        Number of symbol table entries: \(numberOfSymbolTableEntries)
        String table offset: \(stringTableOffset.hexRepresentation)
        String table size: \(stringTableSize)
        """
    }
    
}
