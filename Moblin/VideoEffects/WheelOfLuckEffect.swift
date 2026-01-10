import Charts
import CoreImage
import SwiftUI

private let sectorColors: [Color] = [.blue, .red, .yellow, .green, .pink, .cyan, .purple, .brown, .mint]

struct WheelOfLuckEffectSector: Identifiable {
    let id: Int
    let weight: Double
    let text: String
    let textAngle: Angle
}

@available(iOS 17, *)
private struct WheelView: View {
    let size: Double
    let sectors: [WheelOfLuckEffectSector]

    var body: some View {
        let offset = size / 3.5
        let font = size / 10
        ZStack {
            Chart(sectors) { sector in
                SectorMark(angle: .value("", sector.weight))
                    .foregroundStyle(sectorColors[sector.id % sectorColors.count])
            }
            Circle()
                .foregroundStyle(.white)
                .frame(width: size / 5, height: size / 5)
            ForEach(sectors) { sector in
                Text(sector.text)
                    .font(.system(size: font))
                    .offset(x: offset)
                    .rotationEffect(sector.textAngle)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ArrowView: View {
    let size: Double

    var body: some View {
        Image(systemName: "location.north.fill")
            .font(.system(size: size / 12))
            .foregroundStyle(.white)
            .rotationEffect(.degrees(270))
    }
}

final class WheelOfLuckEffect: VideoEffect {
    private var wheel: CIImage?
    private var arrow: CIImage?
    private var startPresentationTimeStamp: Double = .infinity
    private var previousPresentationTimeStamp: Double = 0
    private var angle: Double = .random(in: 0 ... .pi * 2)
    private var spinTime: Double = .random(in: 12 ... 17)
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())

    init(canvasSize: CGSize) {
        super.init()
        let inputSectors = [
            WheelOfLuckEffectSector(id: 0,
                                    weight: 1,
                                    text: "VIP",
                                    textAngle: .zero),
            WheelOfLuckEffectSector(id: 1,
                                    weight: 2,
                                    text: "BAN",
                                    textAngle: .zero),
            WheelOfLuckEffectSector(id: 2,
                                    weight: 1.5,
                                    text: "Timeout",
                                    textAngle: .zero),
            WheelOfLuckEffectSector(id: 3,
                                    weight: 1,
                                    text: "Special",
                                    textAngle: .zero),
        ]
        let size = 500.0 * (canvasSize.width / 1920)
        var sectors: [WheelOfLuckEffectSector] = []
        let totalWeight = inputSectors.reduce(0) { $0 + $1.weight }
        var angle = 0.0
        for (index, inputSector) in inputSectors.enumerated() {
            let ratio = inputSector.weight / totalWeight
            let textAngle = angle + ratio * 360 / 2 - 90
            angle += ratio * 360
            sectors.append(WheelOfLuckEffectSector(id: index,
                                                   weight: inputSector.weight,
                                                   text: inputSector.text,
                                                   textAngle: .degrees(textAngle)))
        }
        render(size: size, sectors: sectors)
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func spin() {
        processorPipelineQueue.async {
            self.spinTime = .random(in: 12 ... 17)
            self.startPresentationTimeStamp = .nan
        }
    }

    override func getName() -> String {
        return "Wheel of luck"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let wheel, let arrow else {
            return image
        }
        updateAngle(info.presentationTimeStamp.seconds)
        let size = wheel.extent.width
        return arrow
            .translated(x: size - arrow.extent.width * 0.7, y: size / 2 - arrow.extent.height / 2)
            .composited(over: wheel
                .translated(x: -size / 2, y: -size / 2)
                .transformed(by: CGAffineTransform(rotationAngle: angle))
                .translated(x: size / 2, y: size / 2)
                .cropped(to: .init(x: 0, y: 0, width: size, height: size)))
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    private func updateAngle(_ presentationTimeStamp: Double) {
        if startPresentationTimeStamp.isInfinite {
            return
        } else if startPresentationTimeStamp.isNaN {
            startPresentationTimeStamp = presentationTimeStamp
        }
        let elapsedSinceStart = presentationTimeStamp - startPresentationTimeStamp
        let ratio = max(1 - elapsedSinceStart / spinTime, 0)
        angle += -8 * ratio * (presentationTimeStamp - previousPresentationTimeStamp)
        previousPresentationTimeStamp = presentationTimeStamp
    }

    private func render(size: Double, sectors: [WheelOfLuckEffectSector]) {
        DispatchQueue.main.async {
            let wheel = self.renderWheel(size: size, sectors: sectors)
            let arrow = self.renderArrow(size: size)
            processorPipelineQueue.async {
                self.wheel = wheel
                self.arrow = arrow
            }
        }
    }

    @MainActor
    private func renderWheel(size: Double, sectors: [WheelOfLuckEffectSector]) -> CIImage? {
        guard #available(iOS 17, *) else {
            return nil
        }
        let renderer = ImageRenderer(content: WheelView(size: size, sectors: sectors))
        guard let image = renderer.uiImage else {
            return nil
        }
        return CIImage(image: image)
    }

    @MainActor
    private func renderArrow(size: Double) -> CIImage? {
        let renderer = ImageRenderer(content: ArrowView(size: size))
        guard let image = renderer.uiImage else {
            return nil
        }
        return CIImage(image: image)
    }
}
