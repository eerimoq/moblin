import AVFoundation
import HaishinKit
import UIKit

private let lutQueue = DispatchQueue(label: "com.eerimoq.widget.cubeLut")

private func convertLut(image: UIImage) throws -> (Float, Data) {
    let width = image.size.width * image.scale
    let height = image.size.height * image.scale
    let dimension = Int(cbrt(Double(width * height)))
    guard Int(width) % dimension == 0, Int(height) % dimension == 0 else {
        throw "LUT image is not a cube"
    }
    guard dimension * dimension * dimension == Int(width * height) else {
        throw "LUT image is not a cube"
    }
    guard let cgImage = image.cgImage else {
        throw "LUT image convertion failed"
    }
    guard let data = cgImage.dataProvider?.data else {
        throw "Failed to get LUT data"
    }
    guard var pixels = CFDataGetBytePtr(data) else {
        throw "Failed to get LUT pixels"
    }
    let componentsPerPixel = cgImage.bitsPerPixel / cgImage.bitsPerComponent
    let hasAlpha = componentsPerPixel == 4
    let numberOfPixels = Int(width * height)
    let numberInputOfComponents = numberOfPixels * componentsPerPixel
    let numberOutputOfComponents = numberOfPixels * 4
    let cube = UnsafeMutablePointer<Float>.allocate(capacity: numberOutputOfComponents)
    if cgImage.bitsPerComponent == 8 {
        convert8BitsPerComponent(
            Int(width),
            Int(height),
            dimension,
            componentsPerPixel,
            pixels,
            cube,
            hasAlpha
        )
    } else if cgImage.bitsPerComponent == 16 {
        convert16BitsPerComponent(
            Int(width),
            Int(height),
            dimension,
            componentsPerPixel,
            pixels,
            cube,
            hasAlpha,
            numberInputOfComponents
        )

    } else {
        throw "LUT image is not 8 or 16 bits per component"
    }
    return (Float(dimension), Data(bytes: cube, count: numberOutputOfComponents * 4))
}

private func convert8BitsPerComponent(
    _ width: Int,
    _ height: Int,
    _ dimension: Int,
    _ componentsPerPixel: Int,
    _ pixels: UnsafePointer<UInt8>,
    _ cube: UnsafeMutablePointer<Float>,
    _ hasAlpha: Bool
) {
    var pixels = pixels
    var cube = cube
    let origCube = cube
    let rows = height / dimension
    let columns = width / dimension
    let original = pixels
    for row in 0 ..< rows {
        for column in 0 ..< columns {
            for lr in 0 ..< dimension {
                pixels = original
                let rowStrides = Int(width) * (row * dimension + lr) * componentsPerPixel
                let columnStrides = column * dimension * componentsPerPixel
                pixels += (rowStrides + columnStrides)
                for _ in 0 ..< dimension {
                    cube.pointee = Float(pixels.pointee) / 255.0
                    cube += 1
                    pixels += 1
                    cube.pointee = Float(pixels.pointee) / 255.0
                    cube += 1
                    pixels += 1
                    cube.pointee = Float(pixels.pointee) / 255.0
                    cube += 1
                    pixels += 1
                    if hasAlpha {
                        cube.pointee = Float(pixels.pointee) / 255.0
                        pixels += 1
                    } else {
                        cube.pointee = 1.0
                    }
                    cube += 1
                }
            }
        }
    }
}

private func convert16BitsPerComponent(
    _ width: Int,
    _ height: Int,
    _ dimension: Int,
    _ componentsPerPixel: Int,
    _ pixels: UnsafePointer<UInt8>,
    _ cube: UnsafeMutablePointer<Float>,
    _ hasAlpha: Bool,
    _ numberInputOfComponents: Int
) {
    var pixels = pixels
    var cube = cube
    let origCube = cube
    let rows = Int(height) / dimension
    let columns = Int(width) / dimension
    pixels.withMemoryRebound(to: UInt16.self, capacity: numberInputOfComponents) { pixels in
        var pixels = pixels
        let original = pixels
        for row in 0 ..< rows {
            for column in 0 ..< columns {
                for lr in 0 ..< dimension {
                    pixels = original
                    let rowStrides = Int(width) * (row * dimension + lr) * componentsPerPixel
                    let columnStrides = column * dimension * componentsPerPixel
                    pixels += (rowStrides + columnStrides)
                    for _ in 0 ..< dimension {
                        cube.pointee = Float(pixels.pointee.littleEndian) / 65535.0
                        cube += 1
                        pixels += 1
                        cube.pointee = Float(pixels.pointee.littleEndian) / 65535.0
                        cube += 1
                        pixels += 1
                        cube.pointee = Float(pixels.pointee.littleEndian) / 65535.0
                        cube += 1
                        pixels += 1
                        if hasAlpha {
                            cube.pointee = Float(pixels.pointee.littleEndian) / 65535.0
                            pixels += 1
                        } else {
                            cube.pointee = 1.0
                        }
                        cube += 1
                    }
                }
            }
        }
    }
}

final class LutEffect: VideoEffect {
    private var filter = CIFilter.colorCubeWithColorSpace()

    override init() {
        super.init()
        name = "LUT"
    }

    func setLut(name: String, image: UIImage) throws {
        let (dimension, data) = try convertLut(image: image)
        logger
            .info("lut: Applying filter \(name) with dimension \(dimension) and data \(data.count)")
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.cubeData = data
        filter.cubeDimension = dimension
        filter.colorSpace = CGColorSpaceCreateDeviceRGB()
        lutQueue.sync {
            self.filter = filter
        }
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        let filter = lutQueue.sync {
            self.filter
        }
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
