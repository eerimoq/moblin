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
    let length = CFDataGetLength(data)
    guard let data = CFDataGetBytePtr(data) else {
        throw "Failed to get LUT pixels"
    }
    var pixels: [Float]
    if cgImage.bitsPerComponent == 8 {
        pixels = stride(from: 0, to: length, by: 1).map { Float(data[$0]) / 255.0 }
    } else if cgImage.bitsPerComponent == 16 {
        pixels = data.withMemoryRebound(to: UInt16.self, capacity: length / 2) { data in
            stride(from: 0, to: length / 2, by: 1).map { Float(data[$0].littleEndian) / 65535.0 }
        }
    } else {
        throw "LUT image is not 8 or 16 bits per pixel component"
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
