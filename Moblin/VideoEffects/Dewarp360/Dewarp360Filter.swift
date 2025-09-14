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
    var outputSize: CGSize = .init(width: 1920, height: 1080)
    var fov: Float = .pi / 2
    var phi: Float = 0 // vertical
    var theta: Float = 0 // horizontal

    override var outputImage: CIImage? {
        guard let inputImage, let kernel else {
            return nil
        }
        return kernel.apply(
            extent: CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height),
            roiCallback: { _, rect in rect },
            image: inputImage,
            arguments: createArguments(inputImage: inputImage)
        )
    }

    private func createArguments(inputImage: CIImage) -> [Any] {
        let inputWidth = Float(inputImage.extent.width)
        let inputHeight = Float(inputImage.extent.height)
        let outputWidth = Float(outputSize.width)
        let outputHeight = Float(outputSize.height)
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
        return [inputWidth,
                inputHeight,
                outputWidth,
                outputHeight,
                fovWidth,
                fovHeight,
                rotation[0].toCiVector(),
                rotation[1].toCiVector(),
                rotation[2].toCiVector()]
    }
}

extension SIMD3<Float> {
    func toCiVector() -> CIVector {
        return CIVector(values: [CGFloat(x), CGFloat(y), CGFloat(z)], count: 3)
    }
}
