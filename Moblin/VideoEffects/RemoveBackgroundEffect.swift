import CoreImage

private struct HsvColor {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
}

private struct FilterSettings {
    let fromHue: Double
    let toHue: Double
    let minimumSaturation: Double
    let minimumBrightness: Double
}

private let minimumSaturationFloor: Double = 0.15
private let minimumBrightnessFloor: Double = 0.10
private let adaptiveThresholdMultiplier: Double = 0.5
private let hueSectorCount: CGFloat = 6
private let greenHueSectorOffset: CGFloat = 2
private let blueHueSectorOffset: CGFloat = 4

private func rgbToHsv(red: Float, green: Float, blue: Float) -> HsvColor {
    let redCG = CGFloat(red)
    let greenCG = CGFloat(green)
    let blueCG = CGFloat(blue)
    let maxColor = max(redCG, max(greenCG, blueCG))
    let minColor = min(redCG, min(greenCG, blueCG))
    let delta = maxColor - minColor
    guard delta > 0 else {
        return .init(hue: 0, saturation: 0, brightness: maxColor)
    }
    let hue: CGFloat
    if maxColor == redCG {
        let rawHueSector = (greenCG - blueCG) / delta
        hue = rawHueSector < 0 ? rawHueSector + hueSectorCount : rawHueSector
    } else if maxColor == greenCG {
        hue = ((blueCG - redCG) / delta) + greenHueSectorOffset
    } else {
        hue = ((redCG - greenCG) / delta) + blueHueSectorOffset
    }
    return .init(
        hue: hue / hueSectorCount,
        saturation: maxColor == 0 ? 0 : delta / maxColor,
        brightness: maxColor
    )
}

private func isHueInRange(hue: CGFloat, fromHue: CGFloat, toHue: CGFloat) -> Bool {
    if fromHue <= toHue {
        return hue >= fromHue && hue <= toHue
    } else {
        return hue >= fromHue || hue <= toHue
    }
}

private func makeFilter(settings: FilterSettings) -> CIColorCubeWithColorSpace {
    let size = 64
    var cube = [Float]()
    cube.reserveCapacity(size * size * size * 4)
    for z in 0 ..< size {
        let blue = Float(z) / Float(size - 1)
        for y in 0 ..< size {
            let green = Float(y) / Float(size - 1)
            for x in 0 ..< size {
                let red = Float(x) / Float(size - 1)
                let hsv = rgbToHsv(red: red, green: green, blue: blue)
                cube.append(red)
                cube.append(green)
                cube.append(blue)
                let matchesGreenScreen = isHueInRange(hue: hsv.hue,
                                                      fromHue: settings.fromHue,
                                                      toHue: settings.toHue) &&
                    hsv.saturation >= settings.minimumSaturation &&
                    hsv.brightness >= settings.minimumBrightness
                cube.append(matchesGreenScreen ? 0 : 1)
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
    private var pendingSettings: FilterSettings?
    private var updating = false

    func setColorRange(from: RgbColor, to: RgbColor) {
        let fromHsv = rgbToHsv(
            red: Float(from.red) / 255,
            green: Float(from.green) / 255,
            blue: Float(from.blue) / 255
        )
        let toHsv = rgbToHsv(
            red: Float(to.red) / 255,
            green: Float(to.green) / 255,
            blue: Float(to.blue) / 255
        )
        let minimumSaturation = max(
            minimumSaturationFloor,
            Double(min(fromHsv.saturation, toHsv.saturation)) * adaptiveThresholdMultiplier
        )
        let minimumBrightness = max(
            minimumBrightnessFloor,
            Double(min(fromHsv.brightness, toHsv.brightness)) * adaptiveThresholdMultiplier
        )
        pendingSettings = FilterSettings(fromHue: from.hue(),
                                         toHue: to.hue(),
                                         minimumSaturation: minimumSaturation,
                                         minimumBrightness: minimumBrightness)
        tryUpdateFilter()
    }

    private func tryUpdateFilter() {
        DispatchQueue.main.async {
            guard !self.updating, let settings = self.pendingSettings else {
                return
            }
            self.pendingSettings = nil
            self.updating = true
            DispatchQueue.global().async {
                let filter = makeFilter(settings: settings)
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

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let filter else {
            return image
        }
        filter.inputImage = image
        return filter.outputImage ?? image
    }
}
