import Foundation

enum WebBrowserResizeHandle: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    case leading, trailing, top, bottom

    var isLeading: Bool {
        self == .leading || self == .topLeading || self == .bottomLeading
    }

    var isTop: Bool {
        self == .top || self == .topLeading || self == .topTrailing
    }

    var isTrailing: Bool {
        self == .trailing || self == .topTrailing || self == .bottomTrailing
    }

    var isBottom: Bool {
        self == .bottom || self == .bottomLeading || self == .bottomTrailing
    }

    static func at(_ point: CGPoint, in size: CGSize) -> Self {
        let horizontal = min(24, size.width / 3)
        let vertical = min(24, size.height / 3)
        if point.x < horizontal {
            if point.y < vertical {
                return .topLeading
            }
            if point.y > size.height - vertical {
                return .bottomLeading
            }
            return .leading
        }
        if point.x > size.width - horizontal {
            if point.y < vertical {
                return .topTrailing
            }
            if point.y > size.height - vertical {
                return .bottomTrailing
            }
            return .trailing
        }
        return point.y < size.height / 2 ? .top : .bottom
    }
}

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
        let height = Self.limit(height, minimum: 100, maximum: size.height)
        return CGRect(x: Self.limit(x, minimum: 0, maximum: 1) * max(size.width - width, 0),
                      y: Self.limit(y, minimum: 0, maximum: 1) * max(size.height - height, 0),
                      width: width,
                      height: height)
    }

    static func defaultFrame(in size: CGSize, bottomInset: Double) -> CGRect {
        let width = limit(250, minimum: 120, maximum: size.width - 6)
        let height = limit(250, minimum: 100, maximum: size.height - bottomInset)
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

    static func resized(_ frame: CGRect, by translation: CGSize, in size: CGSize,
                        handle: WebBrowserResizeHandle = .bottomTrailing) -> CGRect
    {
        let left = handle.isLeading
            ? limit(frame.minX + translation.width, minimum: 0, maximum: frame.maxX - min(120, size.width))
            : frame.minX
        let top = handle.isTop
            ? limit(frame.minY + translation.height, minimum: 0, maximum: frame.maxY - min(100, size.height))
            : frame.minY
        let width = handle.isLeading
            ? frame.maxX - left
            : (handle.isTrailing
                ? limit(frame.width + translation.width, minimum: 120, maximum: size.width - left)
                : frame.width)
        let height = handle.isTop
            ? frame.maxY - top
            : (handle.isBottom
                ? limit(frame.height + translation.height, minimum: 100, maximum: size.height - top)
                : frame.height)
        return CGRect(x: left, y: top, width: width, height: height)
    }
}
