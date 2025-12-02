import CoreLocation
import Foundation

class RealtimeIrl {
    private let pushUrl: URL
    private let stopUrl: URL
    private var updateCount = 0
    private var pedometerStepsWatch: (value: Int, date: Date)?
    private var pedometerStepsDevice: (value: Int, date: Date)?
    private var heartRateWatch: (value: Int, date: Date)?
    private var heartRateDevice: (value: Int, date: Date)?
    private var cyclingPowerWatch: (value: Int, date: Date)?
    private var cyclingPowerDevice: (value: Int, date: Date)?
    private var cyclingCrankWatch: (value: Int, date: Date)?
    private var cyclingCrankDevice: (value: Int, date: Date)?
    private var cyclingWheelWatch: (value: Int, date: Date)?
    private var cyclingWheelDevice: (value: Int, date: Date)?

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

    private func watchFirst(
        watch: (value: Int, date: Date)?,
        device: (value: Int, date: Date)?
    ) -> Int? {
        if let watch {
            return watch.value
        }
        if let device {
            return device.value
        }
        return nil
    }

    private var pedometerSteps: Int? { watchFirst(watch: pedometerStepsWatch, device: pedometerStepsDevice) }
    private var heartRate: Int? { watchFirst(watch: heartRateWatch, device: heartRateDevice) }
    private var cyclingPower: Int? { watchFirst(watch: cyclingPowerWatch, device: cyclingPowerDevice) }
    private var cyclingCrank: Int? { watchFirst(watch: cyclingCrankWatch, device: cyclingCrankDevice) }
    private var cyclingWheel: Int? { watchFirst(watch: cyclingWheelWatch, device: cyclingWheelDevice) }

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
            pedometerStepsWatch = (steps, Date())
        } else {
            pedometerStepsDevice = (steps, Date())
        }
    }

    func updateHeartRate(_ heartRate: Int, fromWatch: Bool = false) {
        if fromWatch {
            heartRateWatch = (heartRate, Date())
        } else {
            heartRateDevice = (heartRate, Date())
        }
    }

    func updateCyclingPower(_ power: Int, fromWatch: Bool = false) {
        if fromWatch {
            cyclingPowerWatch = (power, Date())
        } else {
            cyclingPowerDevice = (power, Date())
        }
    }

    func updateCyclingCrank(_ cadence: Int, fromWatch: Bool = false) {
        if fromWatch {
            cyclingCrankWatch = (cadence, Date())
        } else {
            cyclingCrankDevice = (cadence, Date())
        }
    }

    func updateCyclingWheel(_ rpm: Int?, fromWatch: Bool = false) {
        if fromWatch {
            if let rpm {
                cyclingWheelWatch = (rpm, Date())
            } else {
                cyclingWheelWatch = nil
            }
        } else {
            if let rpm {
                cyclingWheelDevice = (rpm, Date())
            } else {
                cyclingWheelDevice = nil
            }
        }
    }

    func stop() {
        updateCount = 0
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
        var request = URLRequest(url: stopUrl)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, _, _ in
        }
        .resume()
    }
}
