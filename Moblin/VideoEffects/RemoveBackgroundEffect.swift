import AVFoundation
import CoreImage
import MetalPetal
import Vision

private func makeFilter(fromHue: CGFloat, toHue: CGFloat) -> CIColorCubeWithColorSpace {
    let size = 64
    var cubeRGB = [Float]()
    for z in 0 ..< size {
        let blue = CGFloat(z) / CGFloat(size - 1)
        for y in 0 ..< size {
            let green = CGFloat(y) / CGFloat(size - 1)
            for x in 0 ..< size {
                let red = CGFloat(x) / CGFloat(size - 1)
                let color = RgbColor(red: Int(255 * red), green: Int(255 * green), blue: Int(255 * blue))
                let hue = color.hue()
                let alpha: CGFloat = (hue >= fromHue && hue <= toHue) ? 0 : 1
                cubeRGB.append(Float(red))
                cubeRGB.append(Float(green))
                cubeRGB.append(Float(blue))
                cubeRGB.append(Float(alpha))
            }
        }
    }
    let colorCubeFilter = CIFilter.colorCubeWithColorSpace()
    colorCubeFilter.cubeData = Data(bytes: cubeRGB, count: cubeRGB.count * 4)
    colorCubeFilter.cubeDimension = Float(size)
    colorCubeFilter.colorSpace = CGColorSpaceCreateDeviceRGB()
    return colorCubeFilter
}

final class RemoveBackgroundEffect: VideoEffect {
    private var filter: CIColorCubeWithColorSpace?
    private var pendingFrom: RgbColor?
    private var pendingTo: RgbColor?
    private var updating = false

    func setTransparent(from: RgbColor, to: RgbColor) {
        pendingFrom = from
        pendingTo = to
        tryUpdateFilter()
    }

    private func tryUpdateFilter() {
        DispatchQueue.main.async {
            guard !self.updating, let fromHue = self.pendingFrom?.hue(), let toHue = self.pendingTo?.hue() else {
                return
            }
            self.pendingFrom = nil
            self.pendingTo = nil
            self.updating = true
            DispatchQueue.global().async {
                let filter = makeFilter(fromHue: fromHue, toHue: toHue)
                mixerLockQueue.async {
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
        return "chroma key filter"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let filter else {
            return image
        }
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
