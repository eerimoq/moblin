import Accelerate
import CoreImage
import MetalPetal
import SwiftCube
import SwiftUI

private let loaderQueue = DispatchQueue(label: "com.eerimoq.mobs.lut-loader")

func interpolate3d(at point: SIMD3<Float>,
                   dimension: Int,
                   _ lut: (Int, Int, Int) -> SIMD3<Float>) -> SIMD3<Float>
{
    let maxIndex = Float(dimension - 1)
    let x = min(max(point.x * maxIndex, 0), maxIndex)
    let y = min(max(point.y * maxIndex, 0), maxIndex)
    let z = min(max(point.z * maxIndex, 0), maxIndex)
    let x0 = Int(floor(x))
    let x1 = min(x0 + 1, dimension - 1)
    let y0 = Int(floor(y))
    let y1 = min(y0 + 1, dimension - 1)
    let z0 = Int(floor(z))
    let z1 = min(z0 + 1, dimension - 1)
    let xd = x - Float(x0)
    let yd = y - Float(y0)
    let zd = z - Float(z0)
    let c00 = lut(x0, y0, z0) * (1 - xd) + lut(x1, y0, z0) * xd
    let c01 = lut(x0, y0, z1) * (1 - xd) + lut(x1, y0, z1) * xd
    let c10 = lut(x0, y1, z0) * (1 - xd) + lut(x1, y1, z0) * xd
    let c11 = lut(x0, y1, z1) * (1 - xd) + lut(x1, y1, z1) * xd
    let c0 = c00 * (1 - yd) + c10 * yd
    let c1 = c01 * (1 - yd) + c11 * yd
    return c0 * (1 - zd) + c1 * zd
}

func makeLutCube(dimension: Int, _ lut: (Int, Int, Int) -> SIMD3<Float>) -> (Float, Data) {
    let newDimension = min(dimension, 64)
    var cube = [SIMD4<Float>](repeating: .zero, count: newDimension * newDimension * newDimension)
    var index = 0
    for blue in 0 ..< newDimension {
        for green in 0 ..< newDimension {
            for red in 0 ..< newDimension {
                let entry: SIMD3<Float>
                if newDimension == dimension {
                    entry = lut(red, green, blue)
                } else {
                    let point = SIMD3(Float(red), Float(green), Float(blue)) / Float(newDimension - 1)
                    entry = interpolate3d(at: point, dimension: dimension, lut)
                }
                cube[index] = SIMD4(entry, 1)
                index += 1
            }
        }
    }
    return (Float(newDimension), Data(bytes: cube, count: cube.count * 16))
}

func lutEffectConvertCube(data: Data) throws -> (Float, Data) {
    let lut = try SC3DLut(fileData: data)
    let dimension = lut.size!
    return makeLutCube(dimension: dimension) { red, green, blue in
        let entry = lut.entries[(blue * dimension + green) * dimension + red]
        return SIMD3(entry.red, entry.green, entry.blue)
    }
}

func lutEffectConvertLut(image: UIImage) throws -> (Float, Data) {
    let width = Int(image.size.width * image.scale)
    let height = Int(image.size.height * image.scale)
    let dimension = Int(cbrt(Double(width * height)))
    guard dimension > 0, width % dimension == 0, height % dimension == 0 else {
        throw String(localized: "LUT image is not a cube")
    }
    guard dimension * dimension * dimension == width * height else {
        throw String(localized: "LUT image is not a cube")
    }
    guard let cgImage = image.cgImage else {
        throw String(localized: "LUT image conversion failed")
    }
    guard let data = cgImage.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
        throw String(localized: "Failed to get LUT pixels")
    }
    guard cgImage.bitsPerComponent == 8 || cgImage.bitsPerComponent == 16 else {
        throw String(localized: "LUT image is not 8 or 16 bits per pixel component")
    }
    let componentsPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
    guard componentsPerPixel == 3 || componentsPerPixel == 4 else {
        throw String(localized: "LUT image is not 3 or 4 components per pixel")
    }
    guard CFDataGetLength(data) >= width * height * cgImage.bitsPerPixel / 8 else {
        throw String(localized: "Failed to get LUT pixels")
    }
    func component(_ index: Int) -> Float {
        if cgImage.bitsPerComponent == 8 {
            return Float(bytes[index]) / 255
        } else {
            let value = UnsafeRawPointer(bytes).loadUnaligned(fromByteOffset: 2 * index, as: UInt16.self)
            return Float(value.littleEndian) / 65535
        }
    }
    let columns = width / dimension
    return withExtendedLifetime(data) {
        makeLutCube(dimension: dimension) { red, green, blue in
            let row = blue / columns * dimension + green
            let column = blue % columns * dimension + red
            let index = (row * width + column) * componentsPerPixel
            return SIMD3(component(index), component(index + 1), component(index + 2))
        }
    }
}

func makeLutCgImage(dimension: Int, cubeData: Data) -> CGImage? {
    let pixelsCount = dimension * dimension * dimension
    guard cubeData.count == pixelsCount * 4 * 4 else {
        return nil
    }
    var cube = [UInt8](repeating: 0, count: pixelsCount * 4)
    cubeData.withUnsafeBytes { rawCube in
        cube.withUnsafeMutableBytes { cube in
            var source = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: rawCube.baseAddress),
                                       height: 1,
                                       width: vImagePixelCount(cube.count),
                                       rowBytes: rawCube.count)
            var destination = vImage_Buffer(data: cube.baseAddress,
                                            height: 1,
                                            width: vImagePixelCount(cube.count),
                                            rowBytes: cube.count)
            vImageConvert_PlanarFtoPlanar8(&source, &destination, 1, 0, vImage_Flags(kvImageNoFlags))
        }
    }
    var pixels = [UInt8](repeating: 0, count: pixelsCount * 4)
    let segmentSize = 4 * dimension
    cube.withUnsafeBytes { cube in
        pixels.withUnsafeMutableBytes { pixels in
            var cubeIndex = 0
            for blue in 0 ..< dimension {
                for green in 0 ..< dimension {
                    let pixelIndex = 4 * (green * dimension * dimension + blue * dimension)
                    pixels.baseAddress!.advanced(by: pixelIndex)
                        .copyMemory(from: cube.baseAddress!.advanced(by: cubeIndex), byteCount: segmentSize)
                    cubeIndex += segmentSize
                }
            }
        }
    }
    let context = CGContext(data: &pixels,
                            width: dimension * dimension,
                            height: dimension,
                            bitsPerComponent: 8,
                            bytesPerRow: dimension * dimension * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    return context?.makeImage()
}

private func makeLutImage(dimension: Int, cubeData: Data) -> MTIImage? {
    guard let cgImage = makeLutCgImage(dimension: dimension, cubeData: cubeData) else {
        return nil
    }
    return MTIImage(cgImage: cgImage, options: [.SRGB: false], isOpaque: true)
}

final class LutEffect: VideoEffect, @unchecked Sendable {
    private var filter: (any CIFilter & CIColorCubeWithColorSpace)?
    private let filterMetalPetal = MTIColorLookupFilter()

    func setLut(
        lut: SettingsColorLut?,
        imageStorage: ImageStorage,
        onError: @escaping @MainActor (String, String?) -> Void
    ) {
        loaderQueue.async {
            do {
                try self.loadLut(lut: lut, imageStorage: imageStorage)
            } catch {
                let subTitle = switch error {
                case SwiftCubeError.couldNotDecodeData:
                    "Not a text file"
                case SwiftCubeError.sizeMissing:
                    "Size missing"
                case let SwiftCubeError.sizeTooBig(size):
                    "Size \(size) too big"
                case SwiftCubeError.oneDimensionalLutNotSupported:
                    "One dimensional LUT not supported"
                case let SwiftCubeError.unsupportedKey(key):
                    "Unsupported key \(key)"
                case SwiftCubeError.invalidType:
                    "Invalid type"
                case SwiftCubeError.typeMissing:
                    "Type missing"
                case let SwiftCubeError.invalidDataPoint(point):
                    "Invalid data point \(point)"
                case let SwiftCubeError.wrongNumberOfDataPoints(count):
                    "Wrong number of data points \(count)"
                case let SwiftCubeError.invalidSyntax(text):
                    "Invalid syntax \(text)"
                default:
                    "\(error)"
                }
                let title = switch lut?.type {
                case .bundled:
                    String(localized: "Failed to load bundled file")
                case .disk:
                    String(localized: "Failed to load .png file")
                case .diskCube:
                    String(localized: "Failed to load .cube file")
                case nil:
                    ""
                }
                DispatchQueue.main.async {
                    onError(title, subTitle)
                }
            }
        }
    }

    override func isEnabled() -> Bool {
        filter != nil
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter?.inputImage = image
        return filter?.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard filterMetalPetal.inputColorLookupTable != nil else {
            return image
        }
        filterMetalPetal.inputImage = image
        return filterMetalPetal.outputImage ?? image
    }

    private func loadLut(lut: SettingsColorLut?, imageStorage: ImageStorage) throws {
        if let lut {
            switch lut.type {
            case .bundled:
                try loadBundledPngLut(lut: lut)
            case .disk:
                try loadDiskPngLut(lut: lut, imageStorage: imageStorage)
            case .diskCube:
                try loadDiskCubeLut(lut: lut, imageStorage: imageStorage)
            }
        } else {
            processorPipelineQueue.async {
                self.filter = nil
                self.filterMetalPetal.inputColorLookupTable = nil
            }
        }
    }

    private func loadBundledPngLut(lut: SettingsColorLut) throws {
        guard let path = Bundle.main.path(forResource: "LUTs.bundle/\(lut.name).png", ofType: nil) else {
            return
        }
        guard let image = UIImage(contentsOfFile: path) else {
            return
        }
        try loadImageLut(image: image)
    }

    private func loadDiskPngLut(lut: SettingsColorLut, imageStorage: ImageStorage) throws {
        let data = try Data(contentsOf: imageStorage.makePath(id: lut.id))
        guard let image = UIImage(data: data) else {
            throw String(localized: "Failed to create LUT image")
        }
        try loadImageLut(image: image)
    }

    private func loadDiskCubeLut(lut: SettingsColorLut, imageStorage: ImageStorage) throws {
        try loadCube(lutEffectConvertCube(data: Data(contentsOf: imageStorage.makePath(id: lut.id))))
    }

    private func loadImageLut(image: UIImage) throws {
        try loadCube(lutEffectConvertLut(image: image))
    }

    private func loadCube(_ cube: (Float, Data)) {
        let (dimension, data) = cube
        nonisolated(unsafe)
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeData = data
        filter.cubeDimension = dimension
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        nonisolated(unsafe)
        let lutImage = makeLutImage(dimension: Int(dimension), cubeData: data)
        processorPipelineQueue.async {
            self.filter = filter
            self.filterMetalPetal.inputColorLookupTable = lutImage
        }
    }
}
