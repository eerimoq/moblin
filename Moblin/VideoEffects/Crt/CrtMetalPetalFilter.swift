import MetalPetal

class CrtMetalPetalFilter: @unchecked Sendable {
    private static let kernel: MTIRenderPipelineKernel = {
        let fragmentFunction = MTIFunctionDescriptor(
            name: "crtMetalPetal",
            libraryURL: MTIDefaultLibraryURLForBundle(Bundle.main)
        )
        return MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: fragmentFunction
        )
    }()

    var inputImage: MTIImage?
    var barrelStrength: Float = 0.1

    var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let width = Float(inputImage.extent.width)
        let height = Float(inputImage.extent.height)
        return CrtMetalPetalFilter.kernel.apply(
            to: [inputImage],
            parameters: [
                "inputWidth": width,
                "inputHeight": height,
                "barrelStrength": barrelStrength,
            ],
            outputTextureDimensions: inputImage.dimensions,
            outputPixelFormat: .unspecified
        )
    }
}
