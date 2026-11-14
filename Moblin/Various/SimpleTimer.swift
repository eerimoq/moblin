import Foundation

class SimpleTimer {
    private let queue: DispatchQueue
    private var timer: (any DispatchSourceTimer)?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    deinit {
        stop()
    }

    func startSingleShot(timeout: Double, handler: @escaping @Sendable () -> Void) {
        stop()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(deadline: .now() + timeout)
        timer!.setEventHandler(handler: handler)
        timer!.activate()
    }

    func startPeriodic(
        interval: Double,
        initial: Double? = nil,
        handler: @escaping @Sendable () -> Void
    ) {
        stop()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(deadline: .now() + (initial ?? interval), repeating: interval)
        timer!.setEventHandler(handler: handler)
        timer!.activate()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
