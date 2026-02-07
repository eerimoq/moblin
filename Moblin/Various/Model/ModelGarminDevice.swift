import Foundation

private let metersPerMile = 1609.344

extension SettingsGarminPaceUnit {
    var suffix: String {
        return rawValue
    }
}

extension SettingsGarminDistanceUnit {
    var suffix: String {
        return rawValue
    }
}

extension Model {
    func allDevicePaces() -> [String: String] {
        var result: [String: String] = [:]
        for (name, metrics) in runMetricsByDeviceName {
            guard let paceSecondsPerMeter = metrics.paceSecondsPerMeter,
                  paceSecondsPerMeter > 0
            else {
                result[name] = "-"
                continue
            }
            let secondsPerUnit: Double
            switch database.garminUnits.paceUnit {
            case .minutesPerKilometer:
                secondsPerUnit = paceSecondsPerMeter * 1000.0
            case .minutesPerMile:
                secondsPerUnit = paceSecondsPerMeter * metersPerMile
            }
            let totalSeconds = max(0, Int(secondsPerUnit.rounded()))
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            let paceValue = String(format: "%d:%02d", minutes, seconds)
            result[name] = "\(paceValue) \(database.garminUnits.paceUnit.suffix)"
        }
        return result
    }

    func allDeviceCadences() -> [String: String] {
        var result: [String: String] = [:]
        for (name, metrics) in runMetricsByDeviceName {
            if let cadence = metrics.cadence {
                result[name] = "\(cadence) spm"
            } else {
                result[name] = "-"
            }
        }
        return result
    }

    func allDeviceRunDistances() -> [String: String] {
        var result: [String: String] = [:]
        for (name, metrics) in runMetricsByDeviceName {
            guard let distanceMeters = metrics.distanceMeters else {
                result[name] = "-"
                continue
            }
            let value: Double
            switch database.garminUnits.distanceUnit {
            case .kilometers:
                value = distanceMeters / 1000.0
            case .miles:
                value = distanceMeters / metersPerMile
            }
            let formatted = String(format: "%.2f", value)
            result[name] = "\(formatted) \(database.garminUnits.distanceUnit.suffix)"
        }
        return result
    }
}
