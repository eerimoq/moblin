import CoreImage
import MetalPetal
import simd

private nonisolated(unsafe) let colorMatrix = MTIColorMatrix(matrix: .init(
    .init(0.393, 0.769, 0.189, 0),
    .init(0.349, 0.686, 0.168, 0),
    .init(0.272, 0.534, 0.131, 0),
    .init(0.0000, 0.0000, 0.0000, 1.0)
), bias: .init(0, 0, 0, 0))

final class SepiaEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sepiaTone()
    private let filterMetalPetal = MTIColorMatrixFilter()

    override init() {
        super.init()
        filterMetalPetal.colorMatrix = colorMatrix
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.intensity = 0.9
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        filterMetalPetal.inputImage = image
        return filterMetalPetal.outputImage ?? image
    }
}
