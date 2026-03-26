import CoreImage

private let barrelKernel: CIWarpKernel? = {
    guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
          let data = try? Data(contentsOf: url)
    else {
        return nil
    }
    return try? CIWarpKernel(functionName: "crtBarrelDistortion", fromMetalLibraryData: data)
}()

class CrtBarrelDistortionFilter: CIFilter {
    var inputImage: CIImage?
    var width: CGFloat = 1
    var strength: Float = 0.1

    override var outputImage: CIImage? {
        guard let inputImage, let barrelKernel else {
            return nil
        }
        let extent = inputImage.extent
        return barrelKernel.apply(
            extent: extent,
            roiCallback: { _, rect in
                rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25)
            },
            image: inputImage,
            arguments: [
                Float(width),
                Float(extent.height),
                strength,
            ]
        )
    }
}
