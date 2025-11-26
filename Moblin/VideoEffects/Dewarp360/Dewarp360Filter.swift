import CoreImage
import simd

private let epsilon = 0.00001

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
    var fieldOfView: Float = .pi / 2
    var pan: Float = 0
    var tilt: Float = 0

    override var outputImage: CIImage? {
        guard let inputImage, let kernel else {
            return nil
        }
        return kernel.apply(
            extent: CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height),
            roiCallback: { _, rect in rect },
            image: inputImage,
            arguments: createArguments(inputImage: inputImage)
        )?.cropped(to: CGRect(x: 0,
                              y: 0,
                              width: outputSize.width - epsilon,
                              height: outputSize.height - epsilon))
    }

    private func createArguments(inputImage: CIImage) -> [Any] {
        let outputWidth = Float(outputSize.width)
        let outputHeight = Float(outputSize.height)
        let fieldOfViewHorizontal = fieldOfView
        let fieldOfViewVertical = outputHeight / outputWidth * fieldOfViewHorizontal
        let fieldOfViewWidth = 2 * tan(fieldOfViewHorizontal / 2)
        let fieldOfViewHeight = 2 * tan(fieldOfViewVertical / 2)
        let rotation = createRotationMatrix()
        return [Float(inputImage.extent.width),
                Float(inputImage.extent.height),
                outputWidth,
                outputHeight,
                fieldOfViewWidth,
                fieldOfViewHeight,
                rotation[0].toCiVector(),
                rotation[1].toCiVector(),
                rotation[2].toCiVector()]
    }

    private func createRotationMatrix() -> float3x3 {
        let cosTheta = cos(pan)
        let sinTheta = sin(pan)
        let cosPhi = cos(-tilt)
        let sinPhi = sin(-tilt)
        let rotationY = float3x3(rows: [.init(cosPhi, 0, -sinPhi),
                                        .init(0, 1, 0),
                                        .init(sinPhi, 0, cosPhi)])
        let rotationZ = float3x3(rows: [.init(cosTheta, -sinTheta, 0),
                                        .init(sinTheta, cosTheta, 0),
                                        .init(0, 0, 1)])
        return rotationY * rotationZ
    }
}

extension SIMD3<Float> {
    func toCiVector() -> CIVector {
        return CIVector(values: [CGFloat(x), CGFloat(y), CGFloat(z)], count: 3)
    }
}
