import BinaryAnalyzer
import MachOLoader
import KLActivityLogger
import vm

class DeinitForStruct {
    
    let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
    
    deinit {
        self.closure()
    }
    
}

struct BinaryExecutor {
    
    let fileUrl: URL
    let executorActivity: Activity
    let deinitHelper: DeinitForStruct
    

    init(parentActivity: Activity, binaryFileUrl: URL) {
        let activity = parentActivity.childActivity(named: "Binary executor")
        self.executorActivity = activity
        self.fileUrl = binaryFileUrl
        self.executorActivity.start()
        
        deinitHelper = DeinitForStruct {
            activity.markAsReadyToFinish()
        }
    }
    
    func execute() throws -> Int32 {
        executorActivity.info("Open \(fileUrl.path)")
        // Parse
        let analyzer = try SimpleBinaryAnalyzer(parentActivity: executorActivity, fileURL: fileUrl)
        let analyzedMachO = try analyzer.analyze().first(where: { $0.binary.isArm64 })!
        
        // Load
        let functionsHandler = FunctionsHandler()
        let functionsTable = functionsHandler.functionsTable().reduce(into: [String: Int]()) { $0[$1.key] = $1.value.intValue }
        let loadedLibrariesStorage = LoadedLibrariesStorage()
        let loader = MachOLoader.Loader(parentActivity: executorActivity,
                                        externaFunctionImplementations: functionsTable,
                                        objectFile: analyzedMachO.binary,
                                        objectFileReader: analyzedMachO.reader,
                                        loadedLibrariesStorage: loadedLibrariesStorage)
        
        
        let loadedBinary = try loader.load()
        if let executable = loadedBinary as? LoadedExecutable {
            // Execute
            let vm = VM()
            return vm.jmp(executable.entrypoint.address)
        }
        else if let library = loadedBinary as? LoadedLibrary {
            executorActivity.info("Loaded library: \(library)")
        }
        else {
            executorActivity.failure("Unsupported binary type: \(analyzedMachO.binary.header.fileType)")
        }
        
        return EXIT_SUCCESS
    }
    
}
