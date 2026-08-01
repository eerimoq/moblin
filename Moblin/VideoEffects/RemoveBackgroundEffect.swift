@preconcurrency import CoreImage
import MetalPetal

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

// Same green screen matching as the Core Image color cube above, but evaluated per pixel. The pixel
// buffers are sampled without sRGB decoding, just as the color cube is looked up in device RGB, so
// both implementations work on the same color values.
private let metalPetalShaderSource = """
#include <metal_stdlib>

using namespace metal;

constant float hueSectorCount = \(hueSectorCount);
constant float greenHueSectorOffset = \(greenHueSectorOffset);
constant float blueHueSectorOffset = \(blueHueSectorOffset);

typedef struct {
    float4 position [[position]];
    float2 textureCoordinate;
} VertexOut;

static float3 rgbToHsv(float3 color) {
    float maxColor = max(color.r, max(color.g, color.b));
    float minColor = min(color.r, min(color.g, color.b));
    float delta = maxColor - minColor;
    if (delta <= 0) {
        return float3(0, 0, maxColor);
    }
    float hue;
    if (maxColor == color.r) {
        float rawHueSector = (color.g - color.b) / delta;
        hue = rawHueSector < 0 ? rawHueSector + hueSectorCount : rawHueSector;
    } else if (maxColor == color.g) {
        hue = ((color.b - color.r) / delta) + greenHueSectorOffset;
    } else {
        hue = ((color.r - color.g) / delta) + blueHueSectorOffset;
    }
    return float3(hue / hueSectorCount,
                  maxColor == 0 ? 0 : delta / maxColor,
                  maxColor);
}

static bool isHueInRange(float hue, float fromHue, float toHue) {
    if (fromHue <= toHue) {
        return hue >= fromHue && hue <= toHue;
    } else {
        return hue >= fromHue || hue <= toHue;
    }
}

fragment float4 removeBackground(VertexOut vertexIn [[stage_in]],
                                 texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                 sampler sourceSampler [[sampler(0)]],
                                 constant float &fromHue [[buffer(0)]],
                                 constant float &toHue [[buffer(1)]],
                                 constant float &minimumSaturation [[buffer(2)]],
                                 constant float &minimumBrightness [[buffer(3)]]) {
    float4 color = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
    float3 hsv = rgbToHsv(color.rgb);
    bool matchesGreenScreen = isHueInRange(hsv.x, fromHue, toHue)
        && hsv.y >= minimumSaturation
        && hsv.z >= minimumBrightness;
    return matchesGreenScreen ? float4(color.rgb, 0) : color;
}
"""

private let metalPetalKernel: MTIRenderPipelineKernel = {
    let libraryUrl = MTILibrarySourceRegistration.shared.registerLibrary(
        source: metalPetalShaderSource,
        compileOptions: nil
    )
    return MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .passthroughVertex,
        fragmentFunctionDescriptor: .init(name: "removeBackground", libraryURL: libraryUrl)
    )
}()

final class RemoveBackgroundEffect: VideoEffect, @unchecked Sendable {
    private var filter: (any CIColorCubeWithColorSpace)?
    private var metalPetalSettings: FilterSettings?
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
        let settings = FilterSettings(fromHue: from.hue(),
                                      toHue: to.hue(),
                                      minimumSaturation: minimumSaturation,
                                      minimumBrightness: minimumBrightness)
        processorPipelineQueue.async {
            self.metalPetalSettings = settings
        }
        pendingSettings = settings
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
        guard let metalPetalSettings else {
            return image
        }
        return metalPetalKernel.apply(
            to: MTIUnpremultiplyAlphaFilter.image(byProcessingImage: image),
            parameters: [
                "fromHue": Float(metalPetalSettings.fromHue),
                "toHue": Float(metalPetalSettings.toHue),
                "minimumSaturation": Float(metalPetalSettings.minimumSaturation),
                "minimumBrightness": Float(metalPetalSettings.minimumBrightness),
            ]
        )
    }
}
