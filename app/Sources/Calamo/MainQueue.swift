import Foundation

/// FIFO hop onto the main actor — Task { @MainActor } would not preserve
/// the ordering the engine's event stream requires.
func onMain(_ body: @escaping @MainActor () -> Void) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated(body)
    }
}

/// .common mode: menu tracking would starve a default-mode timer.
func repeatOnMain(every interval: TimeInterval, _ body: @escaping @MainActor () -> Void) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: true) { _ in onMain(body) }
    RunLoop.main.add(timer, forMode: .common)
    return timer
}
