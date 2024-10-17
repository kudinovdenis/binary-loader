import BinaryUtils
import KLActivityLogger

final class ExportsTrie {
    
    final class Node {
        let currentStringValue: String
        let data: Data?
        
        let child: [Node]
        
        init(currentStringValue: String, data: Data?, child: [Node]) {
            self.currentStringValue = currentStringValue
            self.data = data
            self.child = child
        }
    }
    
    private let trieActivity: Activity
    private let baseMemoryEditor: MemoryEditor
    
    init(parentActivity: Activity, memoryEditor: MemoryEditor) throws {
        trieActivity = parentActivity.childActivity(named: "Exports Trie")
        trieActivity.start()
        baseMemoryEditor = memoryEditor
        do {
            trieActivity.debug("Parsing tree")
            let root = try parseNextNode(memoryEditor: memoryEditor)
            trieActivity.debug("Done. Root: \(root)")
        }
        catch {
            trieActivity.debug("Unable to parse tree: \(error)")
            trieActivity.markAsReadyToFinish()
            throw error
        }
    }
    
    deinit {
        trieActivity.markAsReadyToFinish()
    }
    
    private func parseNextNode(memoryEditor: MemoryEditor, edgeString: String = "") throws -> Node {
        let hexRepresentation = try memoryEditor.hexRepresentation(ofNext: 100, alignment: 8)
        trieActivity.debug("\(hexRepresentation)")
        let nodeDataSize: UInt16 = try memoryEditor.readNext()
        var nodeData: Data? = nil
        if nodeDataSize > 0 {
            nodeData = try memoryEditor.readNext(nodeDataSize)
        }
        let childrenCount: UInt16 = try memoryEditor.readNext()
        var children: [Node] = []
        for i in 0..<childrenCount {
            let childEdgeString = try memoryEditor.readNextNullTerminatedString()
            let childOffset: UInt16 = try memoryEditor.readNext()
            
            let newMemoryEditor = try baseMemoryEditor.child(startingAt: childOffset)
            let childNode = try parseNextNode(memoryEditor: memoryEditor, edgeString: edgeString + childEdgeString)
            children.append(childNode)
        }

        let node = Node(currentStringValue: edgeString, data: nodeData, child: children)
        return node
    }
    
}
