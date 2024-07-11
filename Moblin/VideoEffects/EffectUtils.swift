import Foundation

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}

func calcX(x: Double, videoWidth: Double) -> CGFloat {
    return toPixels(x, videoWidth)
}

func calcY(y: Double, height: Double, videoHeight: Double) -> CGFloat {
    return videoHeight - toPixels(y + height, videoHeight)
}
