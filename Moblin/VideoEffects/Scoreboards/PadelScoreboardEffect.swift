import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    let home: Int
    let away: Int

    func isHomeWin() -> Bool {
        return isSetWin(first: home, second: away)
    }

    func isAwayWin() -> Bool {
        return isSetWin(first: away, second: home)
    }
}

struct PadelScoreboardPlayer: Identifiable {
    let id: UUID = .init()
    let name: String
}

struct PadelScoreboardTeam {
    let players: [PadelScoreboardPlayer]
}

struct PadelScoreboard {
    let home: PadelScoreboardTeam
    let away: PadelScoreboardTeam
    let score: [PadelScoreboardScore]
}

private struct TeamScoreView: View {
    var score: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(String(score))
            Spacer(minLength: 0)
        }
    }
}

final class PadelScoreboardEffect: VideoEffect {
    private var scoreBoard: Atomic<CIImage?> = .init(nil)
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)

    override func getName() -> String {
        return "padel scoreboard"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    func update(scoreboard: PadelScoreboard) {
        DispatchQueue.main.async {
            let scoreBoard = VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Spacer(minLength: 0)
                            ForEach(scoreboard.home.players) { player in
                                Text(player.name.uppercased())
                            }
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading) {
                            Spacer(minLength: 0)
                            ForEach(scoreboard.away.players) { player in
                                Text(player.name.uppercased())
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .font(.system(size: 25))
                    ForEach(scoreboard.score) { score in
                        VStack {
                            TeamScoreView(score: score.home)
                                .bold(score.isHomeWin())
                            TeamScoreView(score: score.away)
                                .bold(score.isAwayWin())
                        }
                        .frame(width: 28)
                        .font(.system(size: 45))
                    }
                    Spacer()
                }
                .padding([.leading, .trailing], 3)
                .padding([.top], 3)
                .background(scoreboardBlueColor)
                HStack {
                    Text("Powered by Moblin")
                        .fontDesign(.monospaced)
                        .font(.system(size: 15))
                        .bold()
                    Spacer()
                }
                .padding([.leading, .trailing], 3)
                .padding([.bottom], 3)
                .background(scoreboardDarkBlueColor)
            }
            .foregroundColor(.white)
            let renderer = ImageRenderer(content: scoreBoard)
            guard let image = renderer.uiImage else {
                return
            }
            guard let ciImage = CIImage(image: image) else {
                return
            }
            self.scoreBoard.mutate { $0 = ciImage }
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard var scoreBoard = scoreBoard.value else {
            return image
        }
        let scale = image.extent.size.maximum() / 1920
        scoreBoard = scoreBoard
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scoreBoard
            .transformed(by: CGAffineTransform(
                translationX: 10 * scale,
                y: image.extent.height - scoreBoard.extent.height - 10 * scale
            ))
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
