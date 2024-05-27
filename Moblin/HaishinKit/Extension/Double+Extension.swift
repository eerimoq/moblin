import Foundation

extension Double {
    func nearestCommonFrameRate() -> Double {
        let commonFrameRates = [24.0, 25.0, 29.0, 30.0, 50.0, 60.0]
        return commonFrameRates.min(by: { abs($0 - self) < abs($1 - self) })!
    }
}
