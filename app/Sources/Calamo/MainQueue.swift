import Foundation

/// FIFO hop onto the main actor — Task { @MainActor } would not preserve
/// the ordering the engine's event stream requires.
func onMain(_ body: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated(body)
    }
}
