import CoreImage
import simd

private let kernel: CIWarpKernel? = {
    guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib") else {
        return nil
    }
    guard let data = try? Data(contentsOf: url) else {
        return nil
    }
    return try? CIWarpKernel(functionName: "dewarp360", fromMetalLibraryData: data)
}()

class Dewarp360Filter: CIFilter {
    var inputImage: CIImage?
    var fov: Float = .pi / 2
    var phi: Float = 0 // vertical
    var theta: Float = 0 // horizontal

    override var outputImage: CIImage? {
        guard let inputImage, let kernel else {
            return nil
        }
        let arguments = createArguments(inputImage: inputImage)
        return kernel.apply(
            extent: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            roiCallback: { _, rect in rect },
            image: inputImage,
            arguments: arguments
        )
    }

    private func createArguments(inputImage: CIImage) -> [Any] {
        let inputWidth = Float(inputImage.extent.width)
        let inputHeight = Float(inputImage.extent.height)
        let outputWidth = Float(1920)
        let outputHeight = Float(1080)
        let fovHorizontal = fov
        let fovVertical = outputHeight / outputWidth * fovHorizontal
        let fovWidth = 2 * tan(fovHorizontal / 2)
        let fovHeight = 2 * tan(fovVertical / 2)
        let cosPhi = cos(-phi)
        let sinPhi = sin(-phi)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        let rotationY = float3x3(rows: [.init(cosPhi, 0, -sinPhi),
                                        .init(0, 1, 0),
                                        .init(sinPhi, 0, cosPhi)])
        let rotationZ = float3x3(rows: [.init(cosTheta, -sinTheta, 0),
                                        .init(sinTheta, cosTheta, 0),
                                        .init(0, 0, 1)])
        let rotation = rotationY * rotationZ
        let rotationRow1 = CIVector(values: [CGFloat(rotation[0, 0]), CGFloat(rotation[0, 1]), CGFloat(rotation[0, 2])],
                                    count: 3)
        let rotationRow2 = CIVector(values: [CGFloat(rotation[1, 0]), CGFloat(rotation[1, 1]), CGFloat(rotation[1, 2])],
                                    count: 3)
        let rotationRow3 = CIVector(values: [CGFloat(rotation[2, 0]), CGFloat(rotation[2, 1]), CGFloat(rotation[2, 2])],
                                    count: 3)
        return [inputWidth,
                inputHeight,
                outputWidth,
                outputHeight,
                fovWidth,
                fovHeight,
                rotationRow1,
                rotationRow2,
                rotationRow3]
    }
}
