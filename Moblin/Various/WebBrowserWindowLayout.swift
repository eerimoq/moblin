import Foundation

struct WebBrowserWindowLayout: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(frame: CGRect, in size: CGSize) {
        x = size.width > frame.width ? frame.minX / (size.width - frame.width) : 0
        y = size.height > frame.height ? frame.minY / (size.height - frame.height) : 0
        width = frame.width
        height = frame.height
    }

    private static func limit(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value.isFinite ? value : minimum, minimum), max(maximum, 0))
    }

    func frame(in size: CGSize) -> CGRect {
        let width = Self.limit(width, minimum: 120, maximum: size.width)
        let height = Self.limit(height, minimum: 90, maximum: size.height)
        return CGRect(x: Self.limit(x, minimum: 0, maximum: 1) * max(size.width - width, 0),
                      y: Self.limit(y, minimum: 0, maximum: 1) * max(size.height - height, 0),
                      width: width,
                      height: height)
    }

    static func defaultFrame(in size: CGSize, bottomInset: Double) -> CGRect {
        let width = limit(250, minimum: 120, maximum: size.width - 6)
        let height = limit(250, minimum: 90, maximum: size.height - bottomInset)
        return CGRect(x: max(size.width - width - 3, 0),
                      y: max(size.height - height - bottomInset, 0),
                      width: width,
                      height: height)
    }

    static func moved(_ frame: CGRect, by translation: CGSize, in size: CGSize) -> CGRect {
        CGRect(x: limit(frame.minX + translation.width, minimum: 0, maximum: size.width - frame.width),
               y: limit(frame.minY + translation.height, minimum: 0, maximum: size.height - frame.height),
               width: frame.width,
               height: frame.height)
    }

    static func resized(_ frame: CGRect, by translation: CGSize, in size: CGSize) -> CGRect {
        CGRect(x: frame.minX,
               y: frame.minY,
               width: limit(frame.width + translation.width, minimum: 120, maximum: size.width - frame.minX),
               height: limit(
                   frame.height + translation.height,
                   minimum: 90,
                   maximum: size.height - frame.minY
               ))
    }
}
