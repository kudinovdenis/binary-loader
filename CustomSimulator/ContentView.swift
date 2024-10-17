import SwiftUI
import BinaryAnalyzer
import KLActivityLogger
import vm

struct ContentView: View {
    
    @State var selectedFileUrl: URL?
    @State var isFileImportetOpened: Bool = false
    @State var exitCode: Int32? = nil
    @State var isLoading: Bool = false
    private let activity: Activity = {
        let activity = StubActivity(name: "Root")
        activity.logLevel = .w
        return activity
    }()
    
    var body: some View {
        VStack {
            if let selectedFileUrl = selectedFileUrl {
                Text("Selected file: \(selectedFileUrl.lastPathComponent)")
            }
            else {
                Text("Select file")
            }
            
            if isLoading {
                ProgressView()
            }
            else {
                Button("Open") {
                    isFileImportetOpened = true
                }
            }
            if let exitCode = exitCode {
                Text("Exit code: \(exitCode)")
            }
        }
        .fileImporter(isPresented: $isFileImportetOpened, allowedContentTypes: [.executable, .unixExecutable, .exe, .item]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    activity.failure("No access to resource")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                selectedFileUrl = url
                isLoading = true
                do {
                    let executor = BinaryExecutor(parentActivity: activity, binaryFileUrl: url)
                    exitCode = try executor.execute()
                }
                catch {
                    activity.failure("Error: \(error)")
                }
                
                isLoading = false 
                
            case .failure(let error):
                activity.failure("Error: \(error)")
            }
        }
    }
}
