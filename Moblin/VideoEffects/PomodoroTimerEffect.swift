import Combine
import SwiftUI

private struct PomodoroTimerView: View {
    @ObservedObject var settings: SettingsWidgetPomodoroTimer
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let canvasSize: CGSize

    private var width: Double {
        toPixels(sceneWidget.layout.size, canvasSize.minimum())
    }

    private var phaseColor: Color {
        settings.phase == .focus ? settings.focusColorColor : settings.breakColorColor
    }

    private var progress: Double {
        let total = settings.totalSecondsForCurrentPhase()
        guard total > 0 else { return 1.0 }
        return Double(settings.secondsRemaining) / Double(total)
    }

    private var timeString: String {
        let minutes = settings.secondsRemaining / 60
        let seconds = settings.secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var phaseLabel: String {
        switch settings.phase {
        case .focus:
            String(localized: "Focus")
        case .shortBreak:
            String(localized: "Break")
        }
    }

    var body: some View {
        let w = width
        let padding = w * 0.06
        let cornerRadius = w * 0.08
        let barHeight = w * 0.07
        let barCornerRadius = barHeight / 2
        let sessionDotSize = w * 0.055

        VStack(alignment: .leading, spacing: w * 0.04) {
            HStack(spacing: w * 0.06) {
                Image(systemName: "timer")
                    .font(.system(size: w * 0.12, weight: .semibold))
                    .foregroundStyle(phaseColor)
                Text(phaseLabel)
                    .font(.system(size: w * 0.12, weight: .semibold))
                    .foregroundStyle(phaseColor)
                Spacer()
                Text(timeString)
                    .font(.system(size: w * 0.18, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.foregroundColorColor)
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(settings.foregroundColorColor.opacity(0.2))
                    .frame(width: w - padding * 2, height: barHeight)
                RoundedRectangle(cornerRadius: barCornerRadius)
                    .fill(phaseColor)
                    .frame(width: max(0, (w - padding * 2) * progress), height: barHeight)
            }
            .frame(width: w - padding * 2, height: barHeight)
            HStack(spacing: sessionDotSize * 0.5) {
                ForEach(0 ..< settings.sessionsCompleted, id: \.self) { _ in
                    Circle()
                        .fill(settings.focusColorColor)
                        .frame(width: sessionDotSize, height: sessionDotSize)
                }
                if settings.isRunning {
                    Circle()
                        .fill(settings.foregroundColorColor.opacity(0.4))
                        .frame(width: sessionDotSize, height: sessionDotSize)
                }
            }
        }
        .padding(padding)
        .frame(width: w)
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
        self.sceneWidget.layout = sceneWidget.layout
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
    }

    func setSettings(settings: SettingsWidgetPomodoroTimer) {
        guard settings !== self.settings else {
            return
        }
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
