import CoreImage
import Metal
import MetalPerformanceShaders

final class BlurKernel: CIImageProcessorKernel {
    override static func process(with inputs: [CIImageProcessorInput]?,
                                 arguments: [String: Any]?,
                                 output: CIImageProcessorOutput) throws
    {
        guard let commandBuffer = output.metalCommandBuffer,
              let input = inputs?.first,
              let sourceTexture = input.metalTexture,
              let destinationTexture = output.metalTexture,
              let radius = arguments?["radius"] as? Float
        else {
            return
        }
        let sigma = radius
        let blur = MPSImageGaussianBlur(device: commandBuffer.device, sigma: sigma)
        blur.encode(commandBuffer: commandBuffer,
                    sourceTexture: sourceTexture,
                    destinationTexture: destinationTexture)
    }
}
