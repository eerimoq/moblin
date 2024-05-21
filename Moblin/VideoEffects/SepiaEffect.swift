import AVFoundation
import MetalPetal
import UIKit
import Vision

private let matrix = MTIColorMatrix(matrix: simd_float4x4(
    .init(0.3588, 0.7044, 0.1368, 0.0),
    .init(0.2990, 0.5870, 0.1140, 0.0),
    .init(0.2392, 0.4696, 0.0912, 0.0),
    .init(0.0000, 0.0000, 0.0000, 1.0)
), bias: .init(0, 0, 0, 0))

final class SepiaEffect: VideoEffect {
    private let filter = CIFilter.sepiaTone()

    override func getName() -> String {
        return "sepia filter"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        filter.inputImage = image
        filter.intensity = 0.9
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image else {
            return image
        }
        let filter = MTIColorMatrixFilter()
        filter.colorMatrix = matrix
        filter.inputImage = image
        return filter.outputImage
    }
}
