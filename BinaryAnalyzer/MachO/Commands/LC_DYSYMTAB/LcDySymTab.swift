public struct LcDySymTab: Command {
    public let type: UInt32
    public let size: UInt32

    /*
     * The symbols indicated by symoff and nsyms of the LC_SYMTAB load command
     * are grouped into the following three groups:
     *    local symbols (further grouped by the module they are from)
     *    defined external symbols (further grouped by the module they are from)
     *    undefined symbols
     *
     * The local symbols are used only for debugging.  The dynamic binding
     * process may have to use them to indicate to the debugger the local
     * symbols for a module that is being bound.
     *
     * The last two groups are used by the dynamic binding process to do the
     * binding (indirectly through the module table and the reference symbol
     * table when this is a dynamically linked shared library file).
     */
    public let ilocalsym: UInt32 /* index to local symbols */
    public let nlocalsym: UInt32 /* number of local symbols */

    public let iextdefsym: UInt32 /* index to externally defined symbols */
    public let nextdefsym: UInt32 /* number of externally defined symbols */

    public let iundefsym: UInt32 /* index to undefined symbols */
    public let nundefsym: UInt32 /* number of undefined symbols */

    /*
     * For the for the dynamic binding process to find which module a symbol
     * is defined in the table of contents is used (analogous to the ranlib
     * structure in an archive) which maps defined external symbols to modules
     * they are defined in.  This exists only in a dynamically linked shared
     * library file.  For executable and object modules the defined external
     * symbols are sorted by name and is use as the table of contents.
     */
    public let tocoff: UInt32    /* file offset to table of contents */
    public let ntoc: UInt32    /* number of entries in table of contents */

    /*
     * To support dynamic binding of "modules" (whole object files) the symbol
     * table must reflect the modules that the file was created from.  This is
     * done by having a module table that has indexes and counts into the merged
     * tables for each module.  The module structure that these two entries
     * refer to is described below.  This exists only in a dynamically linked
     * shared library file.  For executable and object modules the file only
     * contains one module so everything in the file belongs to the module.
     */
    public let modtaboff: UInt32    /* file offset to module table */
    public let nmodtab: UInt32    /* number of module table entries */

    /*
     * To support dynamic module binding the module structure for each module
     * indicates the external references (defined and undefined) each module
     * makes.  For each module there is an offset and a count into the
     * reference symbol table for the symbols that the module references.
     * This exists only in a dynamically linked shared library file.  For
     * executable and object modules the defined external symbols and the
     * undefined external symbols indicates the external references.
     */
    public let extrefsymoff: UInt32    /* offset to referenced symbol table */
    public let nextrefsyms: UInt32    /* number of referenced symbol table entries */

    /*
     * The sections that contain "symbol pointers" and "routine stubs" have
     * indexes and (implied counts based on the size of the section and fixed
     * size of the entry) into the "indirect symbol" table for each pointer
     * and stub.  For every section of these two types the index into the
     * indirect symbol table is stored in the section header in the field
     * reserved1.  An indirect symbol table entry is simply a 32bit index into
     * the symbol table to the symbol that the pointer or stub is referring to.
     * The indirect symbol table is ordered to match the entries in the section.
     */
    public let indirectsymoff: UInt32 /* file offset to the indirect symbol table */
    public let nindirectsyms: UInt32  /* number of indirect symbol table entries */

    /*
     * To support relocating an individual module in a library file quickly the
     * external relocation entries for each module in the library need to be
     * accessed efficiently.  Since the relocation entries can't be accessed
     * through the section headers for a library file they are separated into
     * groups of local and external entries further grouped by module.  In this
     * case the presents of this load command who's extreloff, nextrel,
     * locreloff and nlocrel fields are non-zero indicates that the relocation
     * entries of non-merged sections are not referenced through the section
     * structures (and the reloff and nreloc fields in the section headers are
     * set to zero).
     *
     * Since the relocation entries are not accessed through the section headers
     * this requires the r_address field to be something other than a section
     * offset to identify the item to be relocated.  In this case r_address is
     * set to the offset from the vmaddr of the first LC_SEGMENT command.
     * For MH_SPLIT_SEGS images r_address is set to the the offset from the
     * vmaddr of the first read-write LC_SEGMENT command.
     *
     * The relocation entries are grouped by module and the module table
     * entries have indexes and counts into them for the group of external
     * relocation entries for that the module.
     *
     * For sections that are merged across modules there must not be any
     * remaining external relocation entries for them (for merged sections
     * remaining relocation entries must be local).
     */
    public let extreloff: UInt32    /* offset to external relocation entries */
    public let nextrel: UInt32    /* number of external relocation entries */

    /*
     * All the local relocation entries are grouped together (they are not
     * grouped by their module since they are only used if the object is moved
     * from it staticly link edited address).
     */
    public let locreloff: UInt32    /* offset to local relocation entries */
    public let nlocrel: UInt32    /* number of local relocation entries */
    
    public let additional: Additional

}

extension LcDySymTab {
    
    public struct Additional: CustomStringConvertible {
        public let indirectSymbols: [UInt32]
        
        public var description: String {
            """
            Indirect symbols table: \(indirectSymbols)
            """
        }
    }
    
}

extension LcDySymTab: CustomStringConvertible {
    
    public var description: String {
        return """
        ilocalsym: \(ilocalsym),
        nlocalsym: \(nlocalsym),
        iextdefsym: \(iextdefsym),
        nextdefsym: \(nextdefsym),
        iundefsym: \(iundefsym),
        nundefsym: \(nundefsym),
        tocoff: \(tocoff.hexRepresentation),
        ntoc: \(ntoc),
        modtaboff: \(modtaboff.hexRepresentation),
        nmodtab: \(nmodtab),
        extrefsymoff: \(extrefsymoff.hexRepresentation),
        nextrefsyms: \(nextrefsyms),
        indirectsymoff: \(indirectsymoff.hexRepresentation),
        nindirectsyms: \(nindirectsyms),
        extreloff: \(extreloff.hexRepresentation),
        nextrel: \(nextrel),
        locreloff: \(locreloff.hexRepresentation),
        nlocrel: \(nlocrel)
        Additional: \(additional)
        """
    }
    
}
