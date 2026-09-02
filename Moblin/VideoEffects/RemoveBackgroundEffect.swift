@preconcurrency import CoreImage
import MetalPetal
import simd

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
        hue >= fromHue && hue <= toHue
    } else {
        hue >= fromHue || hue <= toHue
    }
}

private func makeFilter(settings: FilterSettings) -> (any CIColorCubeWithColorSpace) {
    let size = 64
    var cube = [Float]()
    cube.reserveCapacity(size * size * size * 4)
    for z in 0 ..< size {
        let blue = Float(z) / Float(size - 1)
        for y in 0 ..< size {
            let green = Float(y) / Float(size - 1)
            for x in 0 ..< size {
                let red = Float(x) / Float(size - 1)
                cube.append(red)
                cube.append(green)
                cube.append(blue)
                let hsv = rgbToHsv(red: red, green: green, blue: blue)
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

private let chromaKeySmoothing: Float = 0.1
private let chromaKeyNeutralAxisMargin: Float = 0.8

private struct ChromaKeySettings {
    let color: MTIColor
    let thresholdSensitivity: Float
}

private func toChroma(_ color: MTIColor) -> SIMD2<Float> {
    let luma = 0.2989 * color.red + 0.5866 * color.green + 0.1145 * color.blue
    return .init(0.7132 * (color.red - luma), 0.5647 * (color.blue - luma))
}

private func makeSaturatedColor(hue: Double) -> MTIColor {
    let sector = Float(hue) * Float(hueSectorCount)
    let secondary = 1 - abs(fmod(sector, 2) - 1)
    let (red, green, blue): (Float, Float, Float) = switch Int(sector) {
    case 0:
        (1, secondary, 0)
    case 1:
        (secondary, 1, 0)
    case 2:
        (0, 1, secondary)
    case 3:
        (0, secondary, 1)
    case 4:
        (secondary, 0, 1)
    default:
        (1, 0, secondary)
    }
    return MTIColor(red: red, green: green, blue: blue, alpha: 1)
}

private func makeChromaKeySettings(from: RgbColor, to: RgbColor) -> ChromaKeySettings {
    let fromHue = from.hue()
    let toHue = to.hue()
    let hueSpan = toHue < fromHue ? toHue - fromHue + 1 : toHue - fromHue
    let color = makeSaturatedColor(hue: (fromHue + hueSpan / 2).truncatingRemainder(dividingBy: 1))
    let chroma = toChroma(color)
    let thresholdSensitivity = min(distance(chroma, toChroma(makeSaturatedColor(hue: fromHue))),
                                   length(chroma) * chromaKeyNeutralAxisMargin)
    return .init(color: color, thresholdSensitivity: thresholdSensitivity)
}

final class RemoveBackgroundEffect: VideoEffect, @unchecked Sendable {
    private var filter: (any CIColorCubeWithColorSpace)?
    private let filterMetalPetal = MTIChromaKeyBlendFilter()
    private var chromaKeySettings: ChromaKeySettings?
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
        nonisolated(unsafe) let chromaKeySettings = makeChromaKeySettings(from: from, to: to)
        processorPipelineQueue.async {
            self.chromaKeySettings = chromaKeySettings
        }
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

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard let chromaKeySettings else {
            return image
        }
        filterMetalPetal.inputImage = image
        filterMetalPetal.inputBackgroundImage = .transparent
        filterMetalPetal.color = chromaKeySettings.color
        filterMetalPetal.thresholdSensitivity = chromaKeySettings.thresholdSensitivity
        filterMetalPetal.smoothing = chromaKeySmoothing
        return filterMetalPetal.outputImage ?? image
    }
}
