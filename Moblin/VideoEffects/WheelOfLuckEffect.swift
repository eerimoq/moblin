import Charts
import CoreImage
import MetalPetal
import SwiftUI

private let wheelSize = 400.0
private let optionColors: [Color] = [.blue, .red, .yellow, .green, .pink, .cyan]

struct WheelOfLuckEffectOption: Identifiable {
    let id: Int
    let weight: Int
    let text: String
    let textAngle: Angle
}

struct WheelOfLuckSpinResult: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
    let name: String
    let message: String
}

private struct PendingSpin {
    let caption: EffectImageCgImage?
    let name: String
    let message: String
}

@available(iOS 17, *)
private struct WheelView: View {
    let size: Double
    let options: [WheelOfLuckEffectOption]

    var body: some View {
        let offset = size / 3.4
        let font = size / 10
        ZStack {
            Chart(options) { option in
                SectorMark(angle: .value("", option.weight))
                    .foregroundStyle(optionColors[option.id % optionColors.count])
            }
            Circle()
                .foregroundStyle(.white)
                .frame(width: size / 5, height: size / 5)
            ForEach(options) { option in
                Text(option.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .font(.system(size: font))
                    .offset(x: offset)
                    .rotationEffect(option.textAngle)
                    .frame(width: 150 * (size / wheelSize))
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

private struct CaptionView: View {
    let size: Double
    let name: String
    let message: String

    var body: some View {
        VStack(spacing: size / 80) {
            if !name.isEmpty {
                Text(name)
                    .bold()
                    .lineLimit(1)
                    .font(.system(size: size / 12))
            }
            if !message.isEmpty {
                Text(message)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .font(.system(size: size / 16))
            }
        }
        .minimumScaleFactor(0.1)
        .foregroundStyle(.white)
        .padding(size / 40)
        .frame(width: size)
        .background(RoundedRectangle(cornerRadius: size / 20).foregroundStyle(.black.opacity(0.6)))
    }
}

final class WheelOfLuckEffect: VideoEffect, @unchecked Sendable {
    private var wheel: EffectImageCgImage?
    private var arrow: EffectImageCgImage?
    private var caption: EffectImageCgImage?
    private var pendingSpins: [PendingSpin] = []
    private var currentSpin: PendingSpin?
    private var options: [WheelOfLuckEffectOption] = []
    private var startPresentationTimeStamp: Double = .infinity
    private var previousPresentationTimeStamp: Double = 0
    private var speed: Double = 0
    private var angle: Double = 0
    private let spinTime: Double = 12
    private let pauseBetweenSpins: Double = 3
    private let showBeforeSpin: Double = 1.5
    private var onlyShowWhenSpinning = false
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private let canvasSize: CGSize
    private let onResult: @MainActor (WheelOfLuckSpinResult) -> Void

    init(canvasSize: CGSize, onResult: @escaping @MainActor (WheelOfLuckSpinResult) -> Void) {
        self.canvasSize = canvasSize
        self.onResult = onResult
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: SettingsWidgetWheelOfLuck) {
        var options: [WheelOfLuckEffectOption] = []
        let totalWeight = Double(settings.totalWeight)
        var angle = 0.0
        for (index, inputOption) in settings.options.enumerated() {
            let ratio = Double(inputOption.weight) / totalWeight
            let textAngle = angle + ratio * 360 / 2 - 90
            angle += ratio * 360
            options.append(WheelOfLuckEffectOption(id: index,
                                                   weight: inputOption.weight,
                                                   text: inputOption.text,
                                                   textAngle: .degrees(textAngle)))
        }
        let onlyShowWhenSpinning = settings.onlyShowWhenSpinning
        processorPipelineQueue.async {
            self.onlyShowWhenSpinning = onlyShowWhenSpinning
        }
        render(size: getSize(), options: options)
    }

    func spin() {
        processorPipelineQueue.async {
            self.pendingSpins.append(PendingSpin(caption: nil, name: "", message: ""))
        }
    }

    func spin(name: String, message: String, count: Int) {
        let size = getSize()
        DispatchQueue.main.async {
            let caption = self.renderCaption(size: size, name: name, message: message)
            processorPipelineQueue.async {
                self.pendingSpins += Array(
                    repeating: PendingSpin(caption: caption, name: name, message: message),
                    count: count
                )
            }
        }
    }

    private func getSize() -> Double {
        wheelSize * (canvasSize.width / 1920)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let wheel = wheel?.getCiImage(), let arrow = arrow?.getCiImage() else {
            return image
        }
        updateAngle(info.presentationTimeStamp.seconds)
        let size = wheel.extent.width
        var output = arrow
            .translated(x: size - arrow.extent.width * 0.7, y: size / 2 - arrow.extent.height / 2)
            .composited(over: wheel
                .translated(x: -size / 2, y: -size / 2)
                .transformed(by: CGAffineTransform(rotationAngle: angle))
                .translated(x: size / 2, y: size / 2)
                .cropped(to: .init(x: 0, y: 0, width: size, height: size)))
            .move(sceneWidget.layout, image.extent.size)
        if let caption = caption?.getCiImage() {
            output = caption
                .translated(x: output.extent.minX + size / 2 - caption.extent.width / 2,
                            y: output.extent.minY - caption.extent.height - size / 40)
                .composited(over: output)
        }
        return output
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let wheel = wheel?.getMetalPetalImage(), let arrow = arrow?.getMetalPetalImage() else {
            return image
        }
        updateAngle(info.presentationTimeStamp.seconds)
        let size = wheel.extent.width
        let arrowSize = arrow.extent.size
        let contentSize = CGSize(width: size + 0.3 * arrowSize.width, height: size)
        let position = layoutCenter(sceneWidget.layout, contentSize, image.extent.size)
        let rotation = Float(-angle)
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        let wheelCenterX = position.x - 0.15 * arrowSize.width
        filter.layers = [
            .init(content: wheel,
                  position: CGPoint(x: wheelCenterX, y: position.y),
                  rotation: rotation),
            .init(content: arrow,
                  position: CGPoint(x: position.x + size / 2 - 0.35 * arrowSize.width,
                                    y: position.y)),
        ]
        if let caption = caption?.getMetalPetalImage() {
            filter.layers.append(.init(content: caption,
                                       position: CGPoint(
                                           x: wheelCenterX,
                                           y: position.y + size / 2 + size / 40 + caption.extent.height / 2
                                       )))
        }
        return filter.outputImage ?? image
    }

    override func isEnabled() -> Bool {
        !onlyShowWhenSpinning || !startPresentationTimeStamp.isInfinite || !pendingSpins.isEmpty
    }

    private func updateAngle(_ presentationTimeStamp: Double) {
        if !startPresentationTimeStamp.isInfinite {
            let elapsedSinceStart = presentationTimeStamp - startPresentationTimeStamp
            if elapsedSinceStart > 0 {
                let ratio = max(1 - elapsedSinceStart / spinTime, 0)
                let previous = max(previousPresentationTimeStamp, startPresentationTimeStamp)
                angle += -speed * ratio * (presentationTimeStamp - previous)
            }
            previousPresentationTimeStamp = presentationTimeStamp
            if elapsedSinceStart >= spinTime, let currentSpin {
                reportResult(spin: currentSpin)
                self.currentSpin = nil
            }
            if elapsedSinceStart >= spinTime + 5 {
                caption = nil
                startPresentationTimeStamp = .infinity
            }
        }
        if !pendingSpins.isEmpty,
           startPresentationTimeStamp.isInfinite
           || presentationTimeStamp - startPresentationTimeStamp >= spinTime + pauseBetweenSpins
        {
            let delay = onlyShowWhenSpinning && startPresentationTimeStamp.isInfinite ? showBeforeSpin : 0
            let spin = pendingSpins.removeFirst()
            currentSpin = spin
            caption = spin.caption
            speed = .random(in: 8 ... 15)
            startPresentationTimeStamp = presentationTimeStamp + delay
            previousPresentationTimeStamp = presentationTimeStamp
        }
    }

    private func reportResult(spin: PendingSpin) {
        let totalWeight = Double(options.reduce(0) { $0 + $1.weight })
        guard totalWeight > 0 else {
            return
        }
        var arrowAngle = (90 + angle * 180 / .pi).truncatingRemainder(dividingBy: 360)
        if arrowAngle < 0 {
            arrowAngle += 360
        }
        var endAngle = 0.0
        var text = options.last?.text ?? ""
        for option in options {
            endAngle += 360 * Double(option.weight) / totalWeight
            if arrowAngle < endAngle {
                text = option.text
                break
            }
        }
        let result = WheelOfLuckSpinResult(text: text, name: spin.name, message: spin.message)
        DispatchQueue.main.async {
            self.onResult(result)
        }
    }

    private func render(size: Double, options: [WheelOfLuckEffectOption]) {
        DispatchQueue.main.async {
            let wheel = self.renderWheel(size: size, options: options)
            let arrow = self.renderArrow(size: size)
            processorPipelineQueue.async {
                self.wheel = wheel
                self.arrow = arrow
                self.options = options
            }
        }
    }

    @MainActor
    private func renderWheel(size: Double, options: [WheelOfLuckEffectOption]) -> EffectImageCgImage? {
        guard #available(iOS 17, *) else {
            return nil
        }
        let renderer = ImageRenderer(content: WheelView(size: size, options: options))
        return renderer.cgImage?.toEffectImage()
    }

    @MainActor
    private func renderCaption(size: Double, name: String, message: String) -> EffectImageCgImage? {
        guard !name.isEmpty || !message.isEmpty else {
            return nil
        }
        let renderer = ImageRenderer(content: CaptionView(size: size, name: name, message: message))
        return renderer.cgImage?.toEffectImage()
    }

    @MainActor
    private func renderArrow(size: Double) -> EffectImageCgImage? {
        let renderer = ImageRenderer(content: ArrowView(size: size))
        return renderer.cgImage?.toEffectImage()
    }
}
