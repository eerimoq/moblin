import AVFoundation
import SwiftCube
import UIKit
import Vision

private func interpolate3d(at point: SIMD3<Float>, in lut: [SIMD3<Float>], dimension: Int) -> SIMD3<Float> {
    let dimensionFloat = Float(dimension)
    let x = min(max(point.x * dimensionFloat - 1, 0), dimensionFloat - 1)
    let y = min(max(point.y * dimensionFloat - 1, 0), dimensionFloat - 1)
    let z = min(max(point.z * dimensionFloat - 1, 0), dimensionFloat - 1)
    let x0 = Int(floor(x))
    let x1 = min(x0 + 1, dimension - 1)
    let y0 = Int(floor(y))
    let y1 = min(y0 + 1, dimension - 1)
    let z0 = Int(floor(z))
    let z1 = min(z0 + 1, dimension - 1)
    let xd = x - Float(x0)
    let yd = y - Float(y0)
    let zd = z - Float(z0)
    let c00 = lut[x0 * dimension * dimension + y0 * dimension + z0] * (1 - xd) +
        lut[x1 * dimension * dimension + y0 * dimension + z0] * xd
    let c01 = lut[x0 * dimension * dimension + y0 * dimension + z1] * (1 - xd) +
        lut[x1 * dimension * dimension + y0 * dimension + z1] * xd
    let c10 = lut[x0 * dimension * dimension + y1 * dimension + z0] * (1 - xd) +
        lut[x1 * dimension * dimension + y1 * dimension + z0] * xd
    let c11 = lut[x0 * dimension * dimension + y1 * dimension + z1] * (1 - xd) +
        lut[x1 * dimension * dimension + y1 * dimension + z1] * xd
    let c0 = c00 * (1 - yd) + c10 * yd
    let c1 = c01 * (1 - yd) + c11 * yd
    return c0 * (1 - zd) + c1 * zd
}

private func convertLutTo64(bigLut: [SIMD3<Float>], bigDimension: Int) -> [SIMD3<Float>] {
    let newPoints = stride(from: 0.0, through: 1.0, by: 1.0 / Float(64 - 1)).map { Float($0) }
    var lut64 = Array(repeating: SIMD3<Float>(0, 0, 0), count: 64 * 64 * 64)
    for i in 0 ..< 64 {
        for j in 0 ..< 64 {
            for k in 0 ..< 64 {
                let point = SIMD3(newPoints[i], newPoints[j], newPoints[k])
                lut64[i * 64 * 64 + j * 64 + k] = interpolate3d(
                    at: point,
                    in: bigLut,
                    dimension: bigDimension
                )
            }
        }
    }
    return lut64
}

private func convertLut(image: UIImage) throws -> (Float, Data) {
    let width = image.size.width * image.scale
    let height = image.size.height * image.scale
    let dimension = Int(cbrt(Double(width * height)))
    guard Int(width) % dimension == 0, Int(height) % dimension == 0 else {
        throw String(localized: "LUT image is not a cube")
    }
    guard dimension * dimension * dimension == Int(width * height) else {
        throw String(localized: "LUT image is not a cube")
    }
    guard let cgImage = image.cgImage else {
        throw String(localized: "LUT image convertion failed")
    }
    guard let data = cgImage.dataProvider?.data else {
        throw String(localized: "Failed to get LUT data")
    }
    let length = CFDataGetLength(data)
    guard let data = CFDataGetBytePtr(data) else {
        throw String(localized: "Failed to get LUT pixels")
    }
    var pixels: [Float]
    if cgImage.bitsPerComponent == 8 {
        pixels = stride(from: 0, to: length, by: 1).map { Float(data[$0]) / 255.0 }
    } else if cgImage.bitsPerComponent == 16 {
        pixels = data.withMemoryRebound(to: UInt16.self, capacity: length / 2) { data in
            stride(from: 0, to: length / 2, by: 1).map { Float(data[$0].littleEndian) / 65535.0 }
        }
    } else {
        throw String(localized: "LUT image is not 8 or 16 bits per pixel component")
    }
    let numberOfPixels = Int(width * height)
    let numberOutputOfComponents = numberOfPixels * 4
    var cube = UnsafeMutablePointer<Float>.allocate(capacity: numberOutputOfComponents)
    let componentsPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
    let hasAlpha = componentsPerPixel == 4
    let originalCube = cube
    let rows = Int(height) / dimension
    let columns = Int(width) / dimension
    for row in 0 ..< rows {
        for column in 0 ..< columns {
            for lr in 0 ..< dimension {
                let rowStrides = Int(width) * (row * dimension + lr) * componentsPerPixel
                let columnStrides = column * dimension * componentsPerPixel
                var index = (rowStrides + columnStrides)
                for _ in 0 ..< dimension {
                    cube.pointee = pixels[index]
                    cube += 1
                    index += 1
                    cube.pointee = pixels[index]
                    cube += 1
                    index += 1
                    cube.pointee = pixels[index]
                    cube += 1
                    index += 1
                    if hasAlpha {
                        cube.pointee = pixels[index]
                        index += 1
                    } else {
                        cube.pointee = 1.0
                    }
                    cube += 1
                }
            }
        }
    }
    return (Float(dimension), Data(bytes: originalCube, count: numberOutputOfComponents * 4))
}

final class LutEffect: VideoEffect {
    private var filter = CIFilter.colorCubeWithColorSpace()

    override func getName() -> String {
        return "LUT"
    }

    func setLut(lut: SettingsColorLut, imageStorage: ImageStorage, onError: @escaping (String, String?) -> Void) {
        DispatchQueue.global().async {
            do {
                try self.loadLut(lut: lut, imageStorage: imageStorage)
            } catch {
                let subTitle: String
                switch error {
                case SwiftCubeError.couldNotDecodeData:
                    subTitle = "Not a text file"
                case SwiftCubeError.sizeMissing:
                    subTitle = "Size missing"
                case let SwiftCubeError.sizeTooBig(size):
                    subTitle = "Size \(size) too big"
                case SwiftCubeError.oneDimensionalLutNotSupported:
                    subTitle = "One dimensional LUT not supported"
                case let SwiftCubeError.unsupportedKey(key):
                    subTitle = "Unsupported key \(key)"
                case SwiftCubeError.invalidType:
                    subTitle = "Invalid type"
                case SwiftCubeError.typeMissing:
                    subTitle = "Type missing"
                case let SwiftCubeError.invalidDataPoint(point):
                    subTitle = "Invalid data point \(point)"
                case let SwiftCubeError.wrongNumberOfDataPoints(count):
                    subTitle = "Wrong number of data points \(count)"
                case let SwiftCubeError.invalidSyntax(text):
                    subTitle = "Invalid syntax \(text)"
                default:
                    subTitle = "\(error)"
                }
                onError(String(localized: "Failed to load .cube file"), subTitle)
            }
        }
    }

    private func loadLut(lut: SettingsColorLut, imageStorage: ImageStorage) throws {
        switch lut.type {
        case .bundled:
            try loadBundledLut(lut: lut)
        case .disk:
            try loadDiskLut(lut: lut, imageStorage: imageStorage)
        case .diskCube:
            try loadDiskCubeLut(lut: lut, imageStorage: imageStorage)
        }
    }

    private func loadBundledLut(lut: SettingsColorLut) throws {
        guard let path = Bundle.main.path(forResource: "LUTs.bundle/\(lut.name).png", ofType: nil) else {
            return
        }
        guard let image = UIImage(contentsOfFile: path) else {
            return
        }
        try loadImageLut(image: image)
    }

    private func loadDiskLut(lut: SettingsColorLut, imageStorage: ImageStorage) throws {
        let data = try Data(contentsOf: imageStorage.makePath(id: lut.id))
        guard let image = UIImage(data: data) else {
            throw String(localized: "Failed to create LUT image")
        }
        try loadImageLut(image: image)
    }

    private func loadDiskCubeLut(lut: SettingsColorLut, imageStorage: ImageStorage) throws {
        var sc3dLut = try SC3DLut(contentsOf: imageStorage.makePath(id: lut.id))
        if sc3dLut.size > 64 {
            let bigLut = sc3dLut.entries.map { entry in SIMD3<Float>(entry.red, entry.green, entry.blue) }
            sc3dLut.entries = convertLutTo64(bigLut: bigLut, bigDimension: sc3dLut.size).map { entry in
                LutEntry(red: entry.x, green: entry.y, blue: entry.z)
            }
            sc3dLut.size = 64
        }
        let filter = try sc3dLut.ciFilter()
        processorPipelineQueue.async {
            self.filter = filter
        }
    }

    private func loadImageLut(image: UIImage) throws {
        let (dimension, data) = try convertLut(image: image)
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeData = data
        filter.cubeDimension = dimension
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        processorPipelineQueue.async {
            self.filter = filter
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
