import MetalPetal
@testable import Moblin
import SwiftCube
import SwiftUI
import Testing

private func makeLut(dimension: Int,
                     _ function: (SIMD3<Float>) -> SIMD3<Float>) -> [SIMD3<Float>]
{
    var lut = [SIMD3<Float>](repeating: .zero, count: dimension * dimension * dimension)
    for blue in 0 ..< dimension {
        for green in 0 ..< dimension {
            for red in 0 ..< dimension {
                let input = SIMD3(Float(red), Float(green), Float(blue)) / Float(dimension - 1)
                lut[blue * dimension * dimension + green * dimension + red] = function(input)
            }
        }
    }
    return lut
}

private func makeCubeData(dimension: Int, _ function: (SIMD3<Float>) -> SIMD3<Float>) -> Data {
    let cube = makeLut(dimension: dimension, function).map { SIMD4($0, 1) }
    return Data(bytes: cube, count: cube.count * 16)
}

private func makeCubeFile(dimension: Int, _ function: (SIMD3<Float>) -> SIMD3<Float>) -> Data {
    var lines = ["TITLE \"Test\"", "LUT_3D_SIZE \(dimension)"]
    for entry in makeLut(dimension: dimension, function) {
        lines.append("\(entry.x) \(entry.y) \(entry.z)")
    }
    return Data(lines.joined(separator: "\n").utf8)
}

private func isEqual(_ actual: SIMD3<Float>, _ expected: SIMD3<Float>, epsilon: Float = 1e-6) -> Bool {
    let difference = actual - expected
    return max(abs(difference.x), abs(difference.y), abs(difference.z)) < epsilon
}

private func identity(_ input: SIMD3<Float>) -> SIMD3<Float> {
    input
}

private func swapRedAndBlue(_ input: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(input.z, input.y, input.x)
}

private func linear(_ input: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(0.25 + 0.5 * input.x, 1 - input.y, 0.1 * input.x + 0.2 * input.y + 0.3 * input.z)
}

private func entry(_ lut: SC3DLut, red: Int, green: Int, blue: Int) -> SIMD3<Float> {
    let entry = lut.entries[(blue * lut.size + green) * lut.size + red]
    return SIMD3(entry.red, entry.green, entry.blue)
}

private func sampler(_ lut: [SIMD3<Float>], dimension: Int) -> (Int, Int, Int) -> SIMD3<Float> {
    { red, green, blue in lut[(blue * dimension + green) * dimension + red] }
}

private func entry(_ cubeData: Data, dimension: Int, red: Int, green: Int, blue: Int) -> SIMD3<Float> {
    let index = 4 * ((blue * dimension + green) * dimension + red)
    return cubeData.withUnsafeBytes { rawCube in
        let cube = rawCube.bindMemory(to: Float.self)
        return SIMD3(cube[index], cube[index + 1], cube[index + 2])
    }
}

struct LutEffectSuite {
    @Test
    func interpolate3dAtGridPoints() {
        let dimension = 5
        let lut = makeLut(dimension: dimension, swapRedAndBlue)
        for blue in 0 ..< dimension {
            for green in 0 ..< dimension {
                for red in 0 ..< dimension {
                    let point = SIMD3(Float(red), Float(green), Float(blue)) / Float(dimension - 1)
                    let value = interpolate3d(
                        at: point,
                        dimension: dimension,
                        sampler(lut, dimension: dimension)
                    )
                    #expect(isEqual(value, lut[blue * dimension * dimension + green * dimension + red]))
                }
            }
        }
    }

    @Test
    func interpolate3dBetweenGridPoints() {
        let dimension = 3
        let lut = makeLut(dimension: dimension, linear)
        for point in [
            SIMD3<Float>(0.1, 0.6, 0.9),
            SIMD3<Float>(0.5, 0.5, 0.5),
            SIMD3<Float>(0.75, 0, 1),
            SIMD3<Float>(0.99, 0.01, 0.4),
        ] {
            let value = interpolate3d(at: point, dimension: dimension, sampler(lut, dimension: dimension))
            #expect(isEqual(value, linear(point)))
        }
    }

    @Test
    func interpolate3dClampsOutOfRangeInput() {
        let lut = sampler(makeLut(dimension: 4, identity), dimension: 4)
        #expect(isEqual(interpolate3d(at: SIMD3(-1, -0.5, -10), dimension: 4, lut), SIMD3(0, 0, 0)))
        #expect(isEqual(interpolate3d(at: SIMD3(1.5, 2, 100), dimension: 4, lut), SIMD3(1, 1, 1)))
    }

    @Test
    func makeBigLutCubeKeepsChannelOrder() {
        let (dimension, cubeData) = makeLutCube(
            dimension: 96,
            sampler(makeLut(dimension: 96, linear), dimension: 96)
        )
        #expect(dimension == 64)
        #expect(cubeData.count == 64 * 64 * 64 * 4 * 4)
        for blue in 0 ..< 64 {
            for green in 0 ..< 64 {
                for red in 0 ..< 64 {
                    let actual = entry(cubeData, dimension: 64, red: red, green: green, blue: blue)
                    let expected = linear(SIMD3(Float(red), Float(green), Float(blue)) / 63)
                    #expect(isEqual(actual, expected))
                }
            }
        }
    }

    @Test
    func convertCubeFile() throws {
        let (dimension, cubeData) = try lutEffectConvertCube(data: makeCubeFile(dimension: 3, swapRedAndBlue))
        #expect(dimension == 3)
        #expect(cubeData.count == 27 * 4 * 4)
        #expect(isEqual(entry(cubeData, dimension: 3, red: 0, green: 0, blue: 0), SIMD3(0, 0, 0)))
        #expect(isEqual(entry(cubeData, dimension: 3, red: 2, green: 0, blue: 0), SIMD3(0, 0, 1)))
        #expect(isEqual(entry(cubeData, dimension: 3, red: 0, green: 1, blue: 0), SIMD3(0, 0.5, 0)))
        #expect(isEqual(entry(cubeData, dimension: 3, red: 0, green: 0, blue: 2), SIMD3(1, 0, 0)))
        #expect(isEqual(entry(cubeData, dimension: 3, red: 2, green: 2, blue: 2), SIMD3(1, 1, 1)))
        cubeData.withUnsafeBytes { rawCube in
            let cube = rawCube.bindMemory(to: Float.self)
            for index in stride(from: 3, to: cube.count, by: 4) {
                #expect(cube[index] == 1)
            }
        }
    }

    @Test
    func convertBigCubeFileTo64() throws {
        let (dimension, cubeData) = try lutEffectConvertCube(data: makeCubeFile(dimension: 65, linear))
        #expect(dimension == 64)
        #expect(cubeData.count == 64 * 64 * 64 * 4 * 4)
        #expect(isEqual(entry(cubeData, dimension: 64, red: 0, green: 0, blue: 0), linear(SIMD3(0, 0, 0))))
        #expect(isEqual(entry(cubeData, dimension: 64, red: 63, green: 0, blue: 0), linear(SIMD3(1, 0, 0))))
        #expect(isEqual(entry(cubeData, dimension: 64, red: 21, green: 42, blue: 63),
                        linear(SIMD3(21 / 63, 42 / 63, 1))))
    }

    @Test
    func convertCubeFileErrors() {
        #expect(throws: SwiftCubeError.self) {
            _ = try lutEffectConvertCube(data: Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8))
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try lutEffectConvertCube(data: Data("LUT_3D_SIZE 2\n0 0 0\n".utf8))
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try lutEffectConvertCube(data: Data([0xFF, 0xFE, 0x00]))
        }
    }

    @Test
    func parseCubeFileFormats() throws {
        let lut = try SC3DLut(fileData: Data("""
        # Created by test\r
        TITLE "My LUT"\r
        \r
        LUT_3D_SIZE 2\r
        \t0 0 0\r
        1.5e-1\t-0.25 +.5  \r
        0.125E+1 100e-3 1E0\r
        0.000001 1. 12345678901234567890
        7e-4 8.50 9
        1 2 3
        4 5 6
        7 8 9
        """.utf8))
        #expect(lut.title == "My LUT")
        #expect(lut.size == 2)
        #expect(lut.entries.count == 8)
        #expect(isEqual(entry(lut, red: 0, green: 0, blue: 0), SIMD3(0, 0, 0)))
        #expect(isEqual(entry(lut, red: 1, green: 0, blue: 0), SIMD3(0.15, -0.25, 0.5)))
        #expect(isEqual(entry(lut, red: 0, green: 1, blue: 0), SIMD3(1.25, 0.1, 1)))
        let big = entry(lut, red: 1, green: 1, blue: 0)
        #expect(isEqual(big.x, 0.000001, epsilon: 1e-12))
        #expect(big.y == 1)
        #expect(isEqual(big.z, 12_345_678_901_234_567_890, epsilon: 1e12))
        #expect(isEqual(entry(lut, red: 0, green: 0, blue: 1), SIMD3(0.0007, 8.5, 9)))
    }

    @Test
    func parseCubeFileSyntaxErrors() {
        for line in ["1 2", "1 2 3 4", "1 2 x", "1e 2 3", "1.2.3 4 5", "- 2 3", "1 2 3;"] {
            #expect(throws: SwiftCubeError.self) {
                _ = try SC3DLut(fileData: Data("LUT_3D_SIZE 1\n\(line)\n".utf8))
            }
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try SC3DLut(fileData: Data("LUT_3D_SIZE 100\n".utf8))
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try SC3DLut(fileData: Data("LUT_3D_SIZE 1\nDOMAIN_MIN 0 0 0\n1 1 1\n".utf8))
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try SC3DLut(fileData: Data("LUT_3D_SIZE 1\nFOO\n1 1 1\n".utf8))
        }
        #expect(throws: SwiftCubeError.self) {
            _ = try SC3DLut(fileData: Data("1 1 1\n".utf8))
        }
    }

    @Test
    func lutImageRoundTrip() throws {
        let dimension = 8
        let (_, cubeData) = try lutEffectConvertCube(data: makeCubeFile(dimension: dimension, linear))
        let cgImage = try #require(makeLutCgImage(dimension: dimension, cubeData: cubeData))
        #expect(cgImage.width == dimension * dimension)
        #expect(cgImage.height == dimension)
        let (convertedDimension, convertedData) = try lutEffectConvertLut(image: UIImage(cgImage: cgImage))
        #expect(convertedDimension == Float(dimension))
        for blue in 0 ..< dimension {
            for green in 0 ..< dimension {
                for red in 0 ..< dimension {
                    let actual = entry(
                        convertedData,
                        dimension: dimension,
                        red: red,
                        green: green,
                        blue: blue
                    )
                    let expected = entry(cubeData, dimension: dimension, red: red, green: green, blue: blue)
                    #expect(isEqual(actual, expected, epsilon: 0.6 / 255))
                }
            }
        }
    }

    @Test
    func convertBigPngLutTo64() throws {
        let dimension = 65
        let cgImage = try #require(makeLutCgImage(dimension: dimension,
                                                  cubeData: makeCubeData(dimension: dimension, linear)))
        let (convertedDimension, convertedData) = try lutEffectConvertLut(image: UIImage(cgImage: cgImage))
        #expect(convertedDimension == 64)
        #expect(convertedData.count == 64 * 64 * 64 * 4 * 4)
        for (red, green, blue) in [
            (0, 0, 0),
            (63, 0, 0),
            (0, 63, 0),
            (0, 0, 63),
            (21, 42, 63),
            (63, 63, 63),
        ] {
            let actual = entry(convertedData, dimension: 64, red: red, green: green, blue: blue)
            let expected = linear(SIMD3(Float(red), Float(green), Float(blue)) / 63)
            #expect(isEqual(actual, expected, epsilon: 0.6 / 255))
        }
    }

    @Test
    func renderCubeLutWithMetalPetal() throws {
        let (dimension, cubeData) = try lutEffectConvertCube(data: makeCubeFile(dimension: 8, swapRedAndBlue))
        let lutCgImage = try #require(makeLutCgImage(dimension: Int(dimension), cubeData: cubeData))
        let filter = MTIColorLookupFilter()
        filter.inputColorLookupTable = MTIImage(cgImage: lutCgImage, options: [.SRGB: false], isOpaque: true)
        filter.inputImage = MTIImage(color: MTIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1),
                                     sRGB: false,
                                     size: CGSize(width: 4, height: 4))
        let outputImage = try #require(filter.outputImage)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            4,
                            4,
                            kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                            &pixelBuffer)
        let metalPetalContext = try MTIContext(device: #require(MTLCreateSystemDefaultDevice()))
        let outputPixelBuffer = try #require(pixelBuffer)
        try metalPetalContext.render(outputImage, to: outputPixelBuffer)
        CVPixelBufferLockBaseAddress(outputPixelBuffer, .readOnly)
        let pixel = try #require(CVPixelBufferGetBaseAddress(outputPixelBuffer))
            .assumingMemoryBound(to: UInt8.self)
        #expect(abs(Int(pixel[0]) - 64) <= 2)
        #expect(abs(Int(pixel[1]) - 128) <= 2)
        #expect(abs(Int(pixel[2]) - 191) <= 2)
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, .readOnly)
    }

    @Test
    func renderBigPngLutWithMetalPetal() throws {
        let size = 2744
        let context = try #require(CGContext(data: nil,
                                             width: size,
                                             height: size,
                                             bitsPerComponent: 8,
                                             bytesPerRow: size * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let pngLut = try #require(context.makeImage())
        let (dimension, cubeData) = try lutEffectConvertLut(image: UIImage(cgImage: pngLut))
        #expect(dimension == 64)
        let lutCgImage = try #require(makeLutCgImage(dimension: Int(dimension), cubeData: cubeData))
        let filter = MTIColorLookupFilter()
        filter.inputColorLookupTable = MTIImage(cgImage: lutCgImage, options: [.SRGB: false], isOpaque: true)
        filter.inputImage = MTIImage(color: MTIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
                                     sRGB: false,
                                     size: CGSize(width: 64, height: 64))
        let outputImage = try #require(filter.outputImage)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            64,
                            64,
                            kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                            &pixelBuffer)
        let metalPetalContext = try MTIContext(device: #require(MTLCreateSystemDefaultDevice()))
        try metalPetalContext.render(outputImage, to: #require(pixelBuffer))
    }

    @Test
    func appleLogToRec709() throws {
        let image = try #require(UIImage(data: readMainFile(
            name: "LUTs.bundle/Apple Log To Rec 709",
            suffix: "png"
        )))
        let (dimension, data) = try lutEffectConvertLut(image: image)
        #expect(dimension == 64)
        #expect(data.count == 4_194_304)
    }

    @Test
    func dither64() throws {
        let image = try #require(UIImage(data: readTestFile(name: "dither64", suffix: "png")))
        #expect(throws: String(localized: "LUT image is not 3 or 4 components per pixel")) {
            _ = try lutEffectConvertLut(image: image)
        }
    }
}
