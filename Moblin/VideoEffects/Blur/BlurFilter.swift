import CoreImage

class BlurFilter: CIFilter {
    var inputImage: CIImage?
    var radius: Float = 8

    override var outputImage: CIImage? {
        guard let inputImage else {
            return nil
        }
        return try? BlurKernel.apply(withExtent: inputImage.extent,
                                     inputs: [inputImage],
                                     arguments: ["radius": radius])
    }
}
