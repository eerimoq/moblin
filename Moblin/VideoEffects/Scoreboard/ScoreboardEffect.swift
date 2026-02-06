import SwiftUI

let scoreboardScoreFontSize = 37.0
let scoreboardScoreBigFontSize = 45.0

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

    var body: some View {
        HStack {
            Text("Powered by Moblin")
                .fontDesign(.monospaced)
                .font(.system(size: 15))
                .bold()
            Spacer()
        }
        .padding([.leading, .trailing], 3)
        .padding([.bottom], 3)
        .background(backgroundColor)
    }
}

final class ScoreboardEffect: VideoEffect {
    private var scoreboardImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    @MainActor
    func update(scoreboard: SettingsWidgetScoreboard,
                config: RemoteControlScoreboardMatchConfig,
                players: [SettingsWidgetScoreboardPlayer])
    {
        switch scoreboard.sport {
        case .generic:
            updateGeneric(textColor: scoreboard.textColorColor,
                          primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                          secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                          generic: scoreboard.generic)
        case .padel:
            updatePadel(textColor: scoreboard.textColorColor,
                        primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                        secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                        padel: scoreboard.padel,
                        players: players)
        default:
            updateModular(modular: scoreboard.modular, config: config)
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let scoreboardImage, let sceneWidget else {
            return image
        }
        let scale = image.extent.size.maximum() / 1920
        return scoreboardImage
            .scaled(x: scale, y: scale)
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
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
                               generic: SettingsWidgetGenericScoreboard)
    {
        let content = ScoreboardEffectGenericView(textColor: textColor,
                                                  primaryBackgroundColor: primaryBackgroundColor,
                                                  secondaryBackgroundColor: secondaryBackgroundColor,
                                                  generic: generic)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updatePadel(textColor: Color,
                             primaryBackgroundColor: Color,
                             secondaryBackgroundColor: Color,
                             padel: SettingsWidgetPadelScoreboard,
                             players: [SettingsWidgetScoreboardPlayer])
    {
        let content = ScoreboardEffectPadelView(textColor: textColor,
                                                primaryBackgroundColor: primaryBackgroundColor,
                                                secondaryBackgroundColor: secondaryBackgroundColor,
                                                padel: padel,
                                                players: players)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }

    @MainActor
    private func updateModular(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) {
        let content = ScoreboardEffectModularView(modular: modular, config: config)
        setScoreboardImage(image: ImageRenderer(content: content).ciImage())
    }
}
