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
                    let point = SIMD3(Float(blue), Float(green), Float(red)) / Float(dimension - 1)
                    let value = interpolate3d(at: point, in: lut, dimension: dimension)
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
            let value = interpolate3d(at: point, in: lut, dimension: dimension)
            #expect(isEqual(value, linear(SIMD3(point.z, point.y, point.x))))
        }
    }

    @Test
    func interpolate3dClampsOutOfRangeInput() {
        let lut = makeLut(dimension: 4, identity)
        #expect(isEqual(interpolate3d(at: SIMD3(-1, -0.5, -10), in: lut, dimension: 4), SIMD3(0, 0, 0)))
        #expect(isEqual(interpolate3d(at: SIMD3(1.5, 2, 100), in: lut, dimension: 4), SIMD3(1, 1, 1)))
    }

    @Test
    func convertIdentityLutTo64() {
        let lut64 = convertLutTo64(bigLut: makeLut(dimension: 65, identity), bigDimension: 65)
        #expect(lut64.count == 64 * 64 * 64)
        for (actual, expected) in zip(lut64, makeLut(dimension: 64, identity)) {
            #expect(isEqual(actual, expected))
        }
    }

    @Test
    func convertLutTo64KeepsChannelOrder() {
        let lut64 = convertLutTo64(bigLut: makeLut(dimension: 96, linear), bigDimension: 96)
        for (actual, expected) in zip(lut64, makeLut(dimension: 64, linear)) {
            #expect(isEqual(actual, expected))
        }
    }

    @Test
    func convertCubeFile() throws {
        let lut = try lutEffectConvertCube(data: makeCubeFile(dimension: 3, swapRedAndBlue))
        #expect(lut.size == 3)
        #expect(lut.entries.count == 27)
        #expect(isEqual(entry(lut, red: 0, green: 0, blue: 0), SIMD3(0, 0, 0)))
        #expect(isEqual(entry(lut, red: 2, green: 0, blue: 0), SIMD3(0, 0, 1)))
        #expect(isEqual(entry(lut, red: 0, green: 1, blue: 0), SIMD3(0, 0.5, 0)))
        #expect(isEqual(entry(lut, red: 0, green: 0, blue: 2), SIMD3(1, 0, 0)))
        #expect(isEqual(entry(lut, red: 2, green: 2, blue: 2), SIMD3(1, 1, 1)))
        let cubeData = makeCubeData(lut.entries)
        #expect(cubeData.count == 27 * 4 * 4)
        #expect(isEqual(entry(cubeData, dimension: 3, red: 2, green: 0, blue: 0), SIMD3(0, 0, 1)))
        cubeData.withUnsafeBytes { rawCube in
            let cube = rawCube.bindMemory(to: Float.self)
            for index in stride(from: 3, to: cube.count, by: 4) {
                #expect(cube[index] == 1)
            }
        }
    }

    @Test
    func convertBigCubeFileTo64() throws {
        let lut = try lutEffectConvertCube(data: makeCubeFile(dimension: 65, linear))
        #expect(lut.size == 64)
        #expect(lut.entries.count == 64 * 64 * 64)
        #expect(isEqual(entry(lut, red: 0, green: 0, blue: 0), linear(SIMD3(0, 0, 0))))
        #expect(isEqual(entry(lut, red: 63, green: 0, blue: 0), linear(SIMD3(1, 0, 0))))
        #expect(isEqual(entry(lut, red: 21, green: 42, blue: 63), linear(SIMD3(21 / 63, 42 / 63, 1))))
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
        let original = try lutEffectConvertCube(data: makeCubeFile(dimension: dimension, linear))
        let cubeData = makeCubeData(original.entries)
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
                    let expected = entry(original, red: red, green: green, blue: blue)
                    #expect(isEqual(actual, expected, epsilon: 0.6 / 255))
                }
            }
        }
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
