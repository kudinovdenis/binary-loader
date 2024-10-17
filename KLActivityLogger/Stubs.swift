public protocol ChildActivityFactory {
    func childActivity(named: String) -> Activity
}

public protocol Activity: ChildActivityFactory {
    func start()
    func markAsReadyToFinish()
    
    func verbose(_ message: String)
    func info(_ message: String)
    func debug(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func failure(_ message: String)
}

public final class StubActivity: Activity {
    
    public enum LogLevel: Int {
        case f, e, w, d, i, v
    }
    
    public var logLevel: LogLevel = .i
    
    private let name: String
    
    public init(name: String) {
        self.name = name
    }
    
    public func childActivity(named: String) -> any Activity {
        let activity = StubActivity(name: named)
        activity.logLevel = logLevel
        return activity
    }
    
    public func start() { verbose("Start") }
    public func markAsReadyToFinish() { verbose("Finish") }
    
    public func verbose(_ message: String) {
        guard logLevel.rawValue >= LogLevel.v.rawValue else {
            return
        }
        print("[V] [\(name)] \(message)")
    }
    
    public func info(_ message: String) {
        guard logLevel.rawValue >= LogLevel.i.rawValue else {
            return
        }
        print("[I] [\(name)] \(message)")
    }
    
    public func debug(_ message: String) {
        guard logLevel.rawValue >= LogLevel.d.rawValue else {
            return
        }
        print("[D] [\(name)] \(message)")
    }
    
    public func warning(_ message: String) {
        guard logLevel.rawValue >= LogLevel.w.rawValue else {
            return
        }
        print("[W] [\(name)] \(message)")
    }
    
    public func error(_ message: String) {
        guard logLevel.rawValue >= LogLevel.e.rawValue else {
            return
        }
        print("[E] [\(name)] \(message)")
    }

    public func failure(_ message: String) {
        guard logLevel.rawValue >= LogLevel.f.rawValue else {
            return
        }
        print("[F] [\(name)] \(message)")
        assertionFailure("[F] [\(name)] \(message)")
    }
    
}
