import CoreLocation
import Foundation

class RealtimeIrl {
    private let pushUrl: URL
    private let stopUrl: URL
    private var updateCount = 0
    private var pedometerStepsWatch: Int?
    private var pedometerStepsDevice: Int?
    private var heartRateWatch: Int?
    private var heartRateDevice: Int?
    private var cyclingPowerWatch: Int?
    private var cyclingPowerDevice: Int?
    private var cyclingCrankWatch: Int?
    private var cyclingCrankDevice: Int?
    private var cyclingWheelWatch: Int?
    private var cyclingWheelDevice: Int?

    private struct Payload: Encodable {
        let latitude: Double
        let longitude: Double
        let speed: Double
        let altitude: Double
        let heading: CLLocationDirection?
        let timestamp: TimeInterval
        let pedometerSteps: Int?
        let heartRate: Int?
        let cyclingPower: Int?
        let cyclingCrank: Int?
        let cyclingWheel: Int?
    }

    private var pedometerSteps: Int? { pedometerStepsWatch ?? pedometerStepsDevice }
    private var heartRate: Int? { heartRateWatch ?? heartRateDevice }
    private var cyclingPower: Int? { cyclingPowerWatch ?? cyclingPowerDevice }
    private var cyclingCrank: Int? { cyclingCrankWatch ?? cyclingCrankDevice }
    private var cyclingWheel: Int? { cyclingWheelWatch ?? cyclingWheelDevice }

    init?(baseUrl: String, pushKey: String) {
        guard let url = URL(string: "\(baseUrl)/push?key=\(pushKey)") else {
            return nil
        }
        pushUrl = url
        guard let url = URL(string: "\(baseUrl)/stop?key=\(pushKey)") else {
            return nil
        }
        stopUrl = url
    }

    func status() -> String {
        if updateCount > 0 {
            return " (\(updateCount))"
        } else {
            return ""
        }
    }

    func update(location: CLLocation) {
        updateCount += 1
        var request = URLRequest(url: pushUrl)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(Payload(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: location.speed,
            altitude: location.altitude,
            heading: location.course,
            pedometerSteps: pedometerSteps,
            heartRate: heartRate,
            cyclingPower: cyclingPower,
            cyclingCrank: cyclingCrank,
            cyclingWheel: cyclingWheel,
            timestamp: location.timestamp.timeIntervalSince1970
        ))
        request.setContentType("application/json")
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }

    func updatePedometerSteps(_ steps: Int, fromWatch: Bool = false) {
        if fromWatch {
            pedometerStepsWatch = steps
        } else {
            pedometerStepsDevice = steps
        }
    }

    func updateHeartRate(_ heartRate: Int, fromWatch: Bool = false) {
        if fromWatch {
            heartRateWatch = heartRate
        } else {
            heartRateDevice = heartRate
        }
    }

    func updateCyclingPower(_ power: Int, fromWatch: Bool = false) {
        if fromWatch {
            cyclingPowerWatch = power
        } else {
            cyclingPowerDevice = power
        }
    }

    func updateCyclingCrank(_ cadence: Int, fromWatch: Bool = false) {
        if fromWatch {
            cyclingCrankWatch = cadence
        } else {
            cyclingCrankDevice = cadence
        }
    }

    func updateCyclingWheel(_ rpm: Int?, fromWatch: Bool = false) {
        if fromWatch {
            cyclingWheelWatch = rpm
        }
        else {
            cyclingWheelDevice = rpm
        }
    }

    private func resetState() {
        pedometerStepsWatch = nil
        pedometerStepsDevice = nil
        heartRateWatch = nil
        heartRateDevice = nil
        cyclingPowerWatch = nil
        cyclingPowerDevice = nil
        cyclingCrankWatch = nil
        cyclingCrankDevice = nil
        cyclingWheelWatch = nil
        cyclingWheelDevice = nil
    }

    func stop() {
        updateCount = 0
        resetState()
        var request = URLRequest(url: stopUrl)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request).resume()
    }
}
