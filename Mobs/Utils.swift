import Foundation
import UIKit

extension String: Error {}

extension String {
    func trim() -> String {
        return trimmingCharacters(in: .whitespaces)
    }
}

extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        return scaledImage
    }
}

func makeRtmpUri(url: String) -> String {
    guard var url = URL(string: url) else {
        return ""
    }
    var components = url.pathComponents
    if components.count < 2 {
        return ""
    }
    components.removeFirst()
    components.removeLast()
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let path = components.joined(separator: "/")
    urlComponents.path = "/\(path)"
    url = urlComponents.url!
    return "\(url)"
}

func makeRtmpStreamName(url: String) -> String {
    let parts = url.split(separator: "/")
    if parts.isEmpty {
        return ""
    }
    return String(parts[parts.count - 1])
}

func replaceSensitive(value: String, sensitive: Bool) -> String {
    if sensitive {
        return value.replacing(/./, with: "*")
    } else {
        return value
    }
}

func widgetImage(widget: SettingsWidget) -> String {
    switch widget.type {
    case .image:
        return "photo"
    case .videoEffect:
        return "camera.filters"
    case .camera:
        return "camera"
    }
}

var sizeFormatter: ByteCountFormatter {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = false
    formatter.countStyle = .decimal
    return formatter
}

func formatBytesPerSecond(speed: Int64) -> String {
    var speed = sizeFormatter.string(fromByteCount: speed)
    speed = speed.replacingOccurrences(of: "bytes", with: "b")
    return speed.replacingOccurrences(of: "B", with: "b") + "ps"
}
