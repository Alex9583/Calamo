import Foundation

enum SyncBridge {
    // Blocks the calling thread until the detached task finishes. Safe only
    // from plain threads (the engine's pipeline thread): calling this from the
    // Swift cooperative pool or the main actor risks starvation or deadlock.
    static func run<T>(_ body: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, any Error>?
        Task.detached(priority: .userInitiated) {
            do { result = .success(try await body()) } catch { result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try result!.get()
    }
}
