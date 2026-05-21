import SwiftUI

let scoreboardScoreFontSize = 37.0
let scoreboardScoreBigFontSize = 45.0

func formatScore(_ score: Int) -> String {
    if score == 0 {
        return String(localized: "E")
    }
    if score > 0 {
        return "+\(score)"
    }
    return "\(score)"
}

struct TeamScoreView: View {
    var score: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(String(score))
            Spacer(minLength: 0)
        }
    }
}

struct PoweredByMoblinView: View {
    let backgroundColor: Color
    let scale: Double

    var body: some View {
        HStack {
            Text("Powered by Moblin")
                .fontDesign(.monospaced)
                .font(.system(size: 15 * scale))
                .bold()
            Spacer()
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 3 * scale)
        .background(backgroundColor)
    }
}

final class ScoreboardEffect: VideoEffect, @unchecked Sendable {
    private let canvasSize: CGSize
    private var scoreboardImage: CIImage?
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var sceneWidgetPipeline = SettingsSceneWidget(widgetId: .init())

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
        self.sceneWidget.layout = sceneWidget.layout
    }

    @MainActor
    func update(scoreboard: SettingsWidgetScoreboard,
                config: RemoteControlScoreboardMatchConfig,
                players: [SettingsWidgetScoreboardPlayer])
    {
        let scale = toPixels(sceneWidget.layout.size, canvasSize.minimum()) / 200
        switch scoreboard.sport {
        case .generic:
            updateGeneric(textColor: scoreboard.textColorColor,
                          primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                          secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                          generic: scoreboard.generic,
                          scale: scale)
        case .padel:
            updatePadel(textColor: scoreboard.textColorColor,
                        primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                        secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                        padel: scoreboard.padel,
                        players: players,
                        scale: scale)
        case .golf:
            updateGolf(textColor: scoreboard.textColorColor,
                       primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                       secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                       golf: scoreboard.golf,
                       scale: scale)
        case .golfFullScorecard:
            updateGolfFullScorecard(textColor: scoreboard.textColorColor,
                                    primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                                    secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                                    golf: scoreboard.golf,
                                    scale: scale)
        default:
            updateModular(modular: scoreboard.modular, config: config, scale: scale)
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        scoreboardImage?
            .move(sceneWidgetPipeline.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    private func setScoreboardImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.scoreboardImage = image
        }
    }

    @MainActor
    private func updateGeneric(textColor: Color,
                               primaryBackgroundColor: Color,
                               secondaryBackgroundColor: Color,
                               generic: SettingsWidgetGenericScoreboard,
                               scale: Double)
    {
        let content = ScoreboardEffectGenericView(textColor: textColor,
                                                  primaryBackgroundColor: primaryBackgroundColor,
                                                  secondaryBackgroundColor: secondaryBackgroundColor,
                                                  generic: generic,
                                                  scale: scale)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updatePadel(textColor: Color,
                             primaryBackgroundColor: Color,
                             secondaryBackgroundColor: Color,
                             padel: SettingsWidgetPadelScoreboard,
                             players: [SettingsWidgetScoreboardPlayer],
                             scale: Double)
    {
        let content = ScoreboardEffectPadelView(textColor: textColor,
                                                primaryBackgroundColor: primaryBackgroundColor,
                                                secondaryBackgroundColor: secondaryBackgroundColor,
                                                padel: padel,
                                                players: players,
                                                scale: scale)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updateModular(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig,
        scale: Double
    ) {
        let content = ScoreboardEffectModularView(modular: modular, config: config, scale: scale)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updateGolf(textColor: Color,
                            primaryBackgroundColor: Color,
                            secondaryBackgroundColor: Color,
                            golf: SettingsWidgetGolfScoreboard,
                            scale: Double)
    {
        let content = ScoreboardEffectGolfView(textColor: textColor,
                                               primaryBackgroundColor: primaryBackgroundColor,
                                               secondaryBackgroundColor: secondaryBackgroundColor,
                                               golf: golf,
                                               scale: scale)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updateGolfFullScorecard(textColor: Color,
                                         primaryBackgroundColor: Color,
                                         secondaryBackgroundColor: Color,
                                         golf: SettingsWidgetGolfScoreboard,
                                         scale: Double)
    {
        let content = ScoreboardEffectGolfFullScorecardView(
            textColor: textColor,
            primaryBackgroundColor: primaryBackgroundColor,
            secondaryBackgroundColor: secondaryBackgroundColor,
            golf: golf,
            scale: scale
        )
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }
}
