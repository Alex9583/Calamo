import CoreServices
import Foundation

/// FSEvents on the file's directory: editors save atomically (write +
/// rename), so the path is watched, never a file descriptor. The stream's
/// latency coalesces the event bursts a single save produces.
final class DictionaryWatcher: @unchecked Sendable {
    private let fileName: String
    private let directory: String
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "calamo.dictionary-watcher")
    private var stream: FSEventStreamRef?

    init(file: URL, onChange: @escaping @Sendable () -> Void) {
        fileName = file.lastPathComponent
        directory = file.deletingLastPathComponent().path
        self.onChange = onChange
    }

    func start() {
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
        guard
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault, changedPaths, &context, [directory] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3,
                FSEventStreamCreateFlags(flags))
        else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    fileprivate func changed(paths: [String]) {
        if paths.contains(where: { $0.hasSuffix("/" + fileName) }) {
            onChange()
        }
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}

private let changedPaths: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
    guard let info else { return }
    let watcher = Unmanaged<DictionaryWatcher>.fromOpaque(info).takeUnretainedValue()
    watcher.changed(paths: unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? [])
}
