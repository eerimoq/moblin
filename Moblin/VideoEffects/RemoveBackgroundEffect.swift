import AVFoundation
import CoreImage
import Vision

private func makeFilter(fromHue: CGFloat, toHue: CGFloat) -> CIColorCubeWithColorSpace {
    let size = 64
    var cube = [Float]()
    for z in 0 ..< size {
        let blue = Float(z) / Float(size - 1)
        for y in 0 ..< size {
            let green = Float(y) / Float(size - 1)
            for x in 0 ..< size {
                let red = Float(x) / Float(size - 1)
                let color = RgbColor(red: Int(255 * red), green: Int(255 * green), blue: Int(255 * blue))
                let hue = color.hue()
                cube.append(red)
                cube.append(green)
                cube.append(blue)
                if fromHue <= toHue {
                    cube.append((hue >= fromHue && hue <= toHue) ? 0 : 1)
                } else {
                    cube.append(hue > fromHue || hue < toHue ? 0 : 1)
                }
            }
        }
    }
    let filter = CIFilter.colorCubeWithColorSpace()
    filter.cubeData = Data(bytes: cube, count: cube.count * 4)
    filter.cubeDimension = Float(size)
    filter.colorSpace = CGColorSpaceCreateDeviceRGB()
    return filter
}

final class RemoveBackgroundEffect: VideoEffect {
    private var filter: CIColorCubeWithColorSpace?
    private var pendingFrom: Double?
    private var pendingTo: Double?
    private var updating = false

    func setColorRange(from: RgbColor, to: RgbColor) {
        pendingFrom = from.hue()
        pendingTo = to.hue()
        tryUpdateFilter()
    }

    private func tryUpdateFilter() {
        DispatchQueue.main.async {
            guard !self.updating, let fromHue = self.pendingFrom, let toHue = self.pendingTo else {
                return
            }
            self.pendingFrom = nil
            self.pendingTo = nil
            self.updating = true
            DispatchQueue.global().async {
                let filter = makeFilter(fromHue: fromHue, toHue: toHue)
                processorPipelineQueue.async {
                    self.filter = filter
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.updating = false
                        self.tryUpdateFilter()
                    }
                }
            }
        }
    }

    override func getName() -> String {
        return "Remove background filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let filter else {
            return image
        }
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
