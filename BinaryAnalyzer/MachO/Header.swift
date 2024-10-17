public struct MachOHeader: CustomStringConvertible {
    public struct Flags: OptionSet {
        public var rawValue: UInt32
        
        static let hasNoUndefinedReferences = 1 << 0
        static let cantBeLinkEditedAgain = 1 << 1
        static let forDynamicLinker = 1 << 2
        static let undefinedRefsAreBoundByDynamicLinker = 1 << 3
        static let hasItsDynamicUndefinedReferencesPrebound = 1 << 4
        static let hasItsReadOnlyAndReadWriteSegmentsSplit = 1 << 5
        static let initRoutineIsToBeRunLazilyViaCatchingMemoryFaultsToItsWriteableSegments = 1 << 6
        static let imageIsUsingTwoLevelNameSpaceBindings = 1 << 7
        static let executableIsForcingAllImagesToUseFlatNameSpaceBindings = 1 << 8
        static let twoLevelNamespaceHintsCanAlwaysBeUsed = 1 << 9
        static let doNotHaveDyldNotifyThePrebindingAgentAboutThisExecutable = 1 << 10
        static let binaryIsNotPreboundButCanHaveItsPrebindingRedone = 1 << 11
        static let binaryBindsToAllTwoLevelNamespaceModulesOfItsDependentLibraries = 1 << 12
        static let safeToDivideUpTheSectionsIntoSubSectionsViaSymbolsForDeadCodeStripping = 1 << 13
        static let binaryHasBeenCanonicalizedViaTheUnPrebindOperation = 1 << 14
        static let finalLinkedImageContainsExternalWeakSymbols = 1 << 15
        static let finalLinkedImageUsesWeakSymbols = 1 << 16
        static let allStacksInTheTaskWillBeGivenStackExecutionPrivilege = 1 << 17
        static let binaryDeclaresItIsSafeForUseInProcessesWithUidZero = 1 << 18
        static let binaryDeclaresItIsSafeForUseInProcessesWhenUgidIsTrue = 1 << 19
        static let theStaticLinkerDoesNotNeedToExamineDependentDylibsToSeeIfAnyAreReExported = 1 << 20
        static let theOsWillLoadTheMainExecutableAtARandomAddress = 1 << 21
        static let theStaticLinkerWillAutomaticallyNotCreateALoadCommandToTheDylibIfNoSymbolsAreBeingReferencedFromTheDylib = 1 << 22
        static let containsASectionOfTypeS_Thread_Local_Variables = 1 << 23
        static let heOsWillRunTheMainExecutableWithANonExecutableHeapEvenOnPlatformsThatDon = 1 << 24
        static let codeWasLinkedForUseInAnApplication = 1 << 25
        static let externalSymbolsListedInTheNlistSymbolTableDoNotIncludeAllTheSymbolsListedInTheDyldInfo = 1 << 26
        static let allowLc_Min_Version_MacosAndLc_Build_VersionLoadCommands = 1 << 27
        static let theDylibIsPartOfTheDyldSharedCacheRatherThanLooseInTheFilesystem = 1 << 31
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
    public let magic: UInt32
    public let cpuType: UInt32
    public let cpuSubType: UInt32
    public let fileType: UInt32
    public let numberOfLoadCommands: UInt32
    public let sizeOfLoadCommands: UInt32
    public let flags: Flags
    public let reserved: UInt32
    
    public var description: String {
        return """
        Magic: \(magic.hexRepresentation)
        Cpu type: \(cpuType.hexRepresentation) \(String(describing: cpuTypeHumanReadable))
        Cpu subtype: \(cpuSubType.hexRepresentation)
        File type: \(fileType.hexRepresentation)
        Number of load commands: \(numberOfLoadCommands)
        Size of load commands: \(sizeOfLoadCommands)
        Flags: \(flags.rawValue.binRepresentation)
        Reserved: \(reserved)
        """
    }
}

extension MachOHeader {
    
    enum CpuType: UInt32, RawRepresentable {
        case arm = 0x100000C
        case x86 = 0x1000007
    }
    
    var cpuTypeHumanReadable: CpuType? {
        return CpuType(rawValue: cpuType)
    }
    
}
