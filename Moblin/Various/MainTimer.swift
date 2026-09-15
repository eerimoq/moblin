import Foundation

@MainActor
class MainTimer {
    private var timer: (any DispatchSourceTimer)?

    nonisolated init() {}

    isolated deinit {
        stop()
    }

    func startSingleShot(timeout: Double, handler: @escaping @MainActor () -> Void) {
        stop()
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer!.schedule(deadline: .now() + timeout)
        timer!.setEventHandler {
            MainActor.assumeIsolated(handler)
        }
        timer!.activate()
    }

    func startPeriodic(
        interval: Double,
        initial: Double? = nil,
        handler: @escaping @MainActor () -> Void
    ) {
        stop()
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer!.schedule(deadline: .now() + (initial ?? interval), repeating: interval)
        timer!.setEventHandler {
            MainActor.assumeIsolated(handler)
        }
        timer!.activate()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
