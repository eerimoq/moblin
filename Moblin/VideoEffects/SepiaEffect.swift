import CoreImage
import MetalPetal
import simd

private let sepiaIntensity: Float = 0.9

// The sepia matrix mixed with the identity matrix by the intensity, just as Core Image's sepia tone
// filter. Core Image applies it in linear color space, so the result differs slightly.
private func makeSepiaColorMatrix() -> MTIColorMatrix {
    // Each column is one output channel's weights.
    let sepia = simd_float4x4(columns: (
        SIMD4<Float>(0.393, 0.769, 0.189, 0),
        SIMD4<Float>(0.349, 0.686, 0.168, 0),
        SIMD4<Float>(0.272, 0.534, 0.131, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ))
    let matrix = sepia * sepiaIntensity + matrix_identity_float4x4 * (1 - sepiaIntensity)
    return MTIColorMatrix(matrix: matrix, bias: SIMD4<Float>(0, 0, 0, 0))
}

final class SepiaEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sepiaTone()
    private let filterMetalPetal = MTIColorMatrixFilter()

    override init() {
        super.init()
        filterMetalPetal.colorMatrix = makeSepiaColorMatrix()
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
