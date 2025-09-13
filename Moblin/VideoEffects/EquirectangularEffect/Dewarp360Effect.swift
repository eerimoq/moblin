import CoreImage

final class Dewarp360Effect: VideoEffect {
    private let filter = Dewarp360Filter()
    private var fov: Float = .init(toRadians(degrees: 90))
    private var phi: Float = 0
    private var theta: Float = 0

    override func getName() -> String {
        return "dewarp 360 filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.fov = fov
        filter.phi = phi
        filter.theta = theta
        return filter.outputImage ?? image
    }
}
