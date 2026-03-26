import CoreImage

private let barrelKernel: CIWarpKernel? = {
    guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
          let data = try? Data(contentsOf: url)
    else {
        return nil
    }
    return try? CIWarpKernel(functionName: "fourThreeBarrelDistortion", fromMetalLibraryData: data)
}()

class FourThreeFilter: CIFilter {
    var inputImage: CIImage?
    var strength: Float = 0.12

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
                Float(extent.width),
                Float(extent.height),
                strength,
            ]
        )
    }
}
