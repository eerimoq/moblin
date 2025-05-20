import CoreMotion

struct GForce: Codable {
    var now: Double
    var recentMax: Double
    var max: Double
}

class GForceManager {
    private let motionManager: CMMotionManager
    private var maximum = 0.0
    private var recentMax = 0.0
    private var recentMaxNow = 0.0
    private var recentMaxProgress = 0.0
    private var now = 0.0
    private var started = false

    init(motionManager: CMMotionManager) {
        self.motionManager = motionManager
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        recentMax = 0.0
        recentMaxNow = 0.0
        recentMaxProgress = 0.0
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let data, error == nil else {
                return
            }
            self.handleAccelerometerUpdate(data: data)
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        motionManager.stopAccelerometerUpdates()
    }

    func getLatest() -> GForce? {
        return GForce(now: now, recentMax: recentMaxNow, max: maximum)
    }

    private func handleAccelerometerUpdate(data: CMAccelerometerData) {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        now = (x * x + y * y + z * z).squareRoot()
        if now > maximum {
            maximum = now
        }
        if now > recentMaxNow {
            recentMaxProgress = 0.0
            recentMax = now
        } else {
            recentMaxProgress += 0.01
            recentMaxProgress = min(recentMaxProgress, 1)
        }
        recentMaxNow = max((1 - easeIn(progress: recentMaxProgress)) * recentMax, now)
    }

    private func easeIn(progress: Double) -> Double {
        return progress * progress * progress * progress
    }
}
