import Foundation

class SimpleTimer {
    private let queue: DispatchQueue
    private var timer: DispatchSourceTimer?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    deinit {
        stop()
    }

    func startSingleShot(timeout: Double, handler: DispatchSourceProtocol.DispatchSourceHandler?) {
        stop()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(deadline: .now() + timeout)
        timer!.setEventHandler(handler: handler)
        timer!.activate()
    }

    func startPeriodic(
        interval: Double,
        initial: Double? = nil,
        handler: DispatchSourceProtocol.DispatchSourceHandler?
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
