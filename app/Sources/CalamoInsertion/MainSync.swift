import Foundation

/// Pasteboard and AX work is main-queue confined; the port is called on the
/// engine's pipeline thread.
@discardableResult
func onMainSync<T>(_ body: () -> T) -> T {
    Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
}
