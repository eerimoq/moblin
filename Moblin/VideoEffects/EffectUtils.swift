import Foundation

func toPosition(percentage: Double, total: Double) -> Double {
    return (percentage * total) / 100
}

func calcX(x: Double, videoWidth: Double) -> CGFloat {
    return toPosition(percentage: x, total: videoWidth)
}

func calcY(y: Double, height: Double, videoHeight: Double) -> CGFloat {
    return videoHeight - toPosition(percentage: y + height, total: videoHeight)
}
