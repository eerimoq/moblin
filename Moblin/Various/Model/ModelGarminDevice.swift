import Foundation

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
            result[name] = formatPace(speed: 1.0 / paceSecondsPerMeter)
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
            result[name] = format(distance: distanceMeters)
        }
        return result
    }
}
