import Foundation

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}
