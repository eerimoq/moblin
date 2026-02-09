import CoreImage

final class RoundedRectangleFactory {
    private var imageBuffers: [String: CIImage] = [:]

    func cornerRadius(_ size: CGSize, cornerRadius: CGFloat) -> CIImage? {
        let key = "\(size.width):\(size.height):\(cornerRadius)"
        if let buffer = imageBuffers[key] {
            return buffer
        }
        let roundedRect = CIFilter.roundedRectangleGenerator()
        roundedRect.extent = .init(origin: .zero, size: size)
        roundedRect.radius = Float(cornerRadius)
        guard
            let image = roundedRect.outputImage else {
            return nil
        }
        imageBuffers[key] = image
        return imageBuffers[key]
    }

    func removeAll() {
        imageBuffers.removeAll()
    }
}
