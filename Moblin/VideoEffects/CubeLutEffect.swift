import AVFoundation
import HaishinKit
import UIKit

final class CubeLutEffect: VideoEffect {
    private let filter = CIFilter.colorCube()
    private var cubeDimension: Float = 1.0
    private var cubeData: Data?

    func setLut(image: UIImage) {
        let imageWidth = image.size.width * image.scale
        let imageHeight = image.size.height * image.scale
        let dimension = Int(cbrt(Double(imageWidth * imageHeight)))
        guard Int(imageWidth) % dimension == 0 && Int(imageHeight) % dimension == 0 else {
            logger.info("cube-lut: Invalid image size")
            return
        }
        guard dimension * dimension * dimension == Int(imageWidth * imageHeight) else {
            logger.info("cube-lut: Invalid image size")
            return
        }
        guard let cgImage = image.cgImage else {
            return
        }
        guard let dataProvider = cgImage.dataProvider else {
            return
        }
        guard let data = dataProvider.data else {
            return
        }
        guard var pixels = CFDataGetBytePtr(data) else {
            return
        }
        let length = CFDataGetLength(data)
        let original = pixels
        let row = Int(imageHeight) / dimension
        let column = Int(imageWidth) / dimension
        var cube = UnsafeMutablePointer<Float>.allocate(capacity: length)
        let origCube = cube
        for r in 0 ..< row {
            for c in 0 ..< column {
                pixels = original
                pixels += Int(imageWidth) * (r * dimension) * 4 + c * dimension * 4
                for lr in 0 ..< dimension {
                    pixels = original
                    let rowStrides = Int(imageWidth) * (r * dimension + lr) * 4
                    let columnStrides = c * dimension * 4
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
                        cube.pointee = Float(pixels.pointee) / 255.0
                        cube += 1
                        pixels += 1
                    }
                }
            }
        }
        cubeDimension = Float(dimension)
        cubeData = Data(bytes: origCube, count: length * 4)
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        guard let cubeData else {
            return image
        }
        filter.inputImage = image
        filter.cubeDimension = cubeDimension
        filter.cubeData = cubeData
        return filter.outputImage ?? image
    }
}
