import MetalPetal

extension MTIImage {
    private static let radialGradientKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .passthroughVertex,
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "radialGradient", in: Bundle.main)
    )

    static func radialGradient(size: CGSize) -> MTIImage {
        return radialGradientKernel.makeImage(dimensions: MTITextureDimensions(cgSize: size))
    }
}
