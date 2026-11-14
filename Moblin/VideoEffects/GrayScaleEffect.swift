import CoreImage
import MetalPetal
import simd

// Luminance (Rec. 709) times the gray color, just as Core Image's color monochrome filter with full
// intensity. Core Image applies it in linear color space, so the result differs slightly.
// Each column is one output channel's weights, so red, green and blue all get the luminance.
private func makeGrayScaleColorMatrix() -> MTIColorMatrix {
    let luminance = SIMD4<Float>(0.2126, 0.7152, 0.0722, 0) * 0.75
    return MTIColorMatrix(matrix: simd_float4x4(columns: (
        luminance,
        luminance,
        luminance,
        SIMD4<Float>(0, 0, 0, 1)
    )), bias: SIMD4<Float>(0, 0, 0, 0))
}

final class GrayScaleEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.colorMonochrome()
    private let filterMetalPetal = MTIColorMatrixFilter()

    override init() {
        super.init()
        filterMetalPetal.colorMatrix = makeGrayScaleColorMatrix()
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        filterMetalPetal.inputImage = image
        return filterMetalPetal.outputImage ?? image
    }
}
