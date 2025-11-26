import AVFoundation

extension CMVideoDimensions: @retroactive Equatable {
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }

    func isPortrait() -> Bool {
        return height > width
    }

    func aspectRatio() -> Double {
        return Double(width) / Double(height)
    }

    func convertTo(dimension: Int32) -> CMVideoDimensions? {
        if isPortrait() {
            var height = height * dimension / width
            if height % 2 == 1 {
                height += 1
            }
            return CMVideoDimensions(width: dimension, height: height)
        } else {
            var width = width * dimension / height
            if width % 2 == 1 {
                width += 1
            }
            return CMVideoDimensions(width: width, height: dimension)
        }
    }

    func toSize() -> CGSize {
        return CGSize(width: Double(width), height: Double(height))
    }
}
