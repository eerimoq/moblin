import Combine
import SwiftUI

private struct PomodoroTimerView: View {
    @ObservedObject var settings: SettingsWidgetPomodoroTimer
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let canvasSize: CGSize

    private var width: Double {
        toPixels(sceneWidget.layout.size, canvasSize.minimum())
    }

    private var progress: Double {
        let total = settings.totalSecondsForCurrentPhase()
        guard total > 0 else {
            return 1.0
        }
        return Double(settings.secondsRemaining) / Double(total)
    }

    private var timeString: String {
        let minutes = settings.secondsRemaining / 60
        let seconds = settings.secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func phaseColor() -> Color {
        switch settings.phase {
        case .focus:
            settings.focusColorColor
        case .shortBreak:
            settings.breakColorColor
        }
    }

    private func phaseIcon() -> String {
        switch settings.phase {
        case .focus:
            settings.focusIcon.rawValue
        case .shortBreak:
            settings.breakIcon.rawValue
        }
    }

    var body: some View {
        let padding = width * 0.06
        let cornerRadius = width * 0.08
        let barHeight = width * 0.07
        let barCornerRadius = barHeight / 2
        let phaseSize = width * 0.15
        let timerSize = width * 0.18
        let spacing = width * 0.04
        let width = 1.6 * width
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: spacing) {
                Image(systemName: phaseIcon())
                    .font(.system(size: phaseSize, weight: .semibold))
                    .foregroundStyle(phaseColor())
                Text(settings.phase.toString())
                    .lineLimit(1)
                    .font(.system(size: phaseSize, weight: .semibold))
                    .foregroundStyle(phaseColor())
                Spacer(minLength: 0)
                Text(timeString)
                    .lineLimit(1)
                    .font(.system(size: timerSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.foregroundColorColor)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(settings.foregroundColorColor.opacity(0.2))
                    .frame(width: width - padding * 2, height: barHeight)
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(phaseColor())
                    .frame(width: max(0, (width - padding * 2) * progress), height: barHeight)
            }
            .frame(width: width - padding * 2, height: barHeight)
        }
        .padding(.top, padding / 2)
        .padding([.horizontal, .bottom], padding)
        .frame(width: width)
        .background(settings.backgroundColorColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

final class PomodoroTimerEffect: VideoEffect, @unchecked Sendable {
    private let canvasSize: CGSize
    private var settings = SettingsWidgetPomodoroTimer()
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var sceneWidgetPipeline = SettingsSceneWidget(widgetId: .init())
    private var renderer: ImageRenderer<PomodoroTimerView>?
    private var cancellable: AnyCancellable?
    private var timerImage: CIImage?

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init()
        DispatchQueue.main.async {
            self.setup()
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
        self.sceneWidget.layout = sceneWidget.layout
    }

    func setSettings(settings: SettingsWidgetPomodoroTimer) {
        self.settings = settings
        DispatchQueue.main.async {
            self.setupRenderer()
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        timerImage?
            .move(sceneWidgetPipeline.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    @MainActor
    private func setup() {
        setupRenderer()
    }

    @MainActor
    private func setupRenderer() {
        renderer = ImageRenderer(content: PomodoroTimerView(settings: settings,
                                                            sceneWidget: sceneWidget,
                                                            canvasSize: canvasSize))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            setTimerImage(image: renderer?.ciImage())
        }
        setTimerImage(image: renderer?.ciImage())
    }

    private func setTimerImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.timerImage = image
        }
    }
}
