import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    let home: Int
    let away: Int
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

final class PadelScoreboardEffect: VideoEffect {
    private var scoreBoard: Atomic<CIImage?> = .init(nil)
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)

    override func getName() -> String {
        return "padel scoreboard"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    func update(scoreBoard: PadelScoreboard) {
        DispatchQueue.main.async {
            let scoreBoard = VStack(alignment: .leading) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Spacer(minLength: 0)
                            ForEach(scoreBoard.home.players) { player in
                                Text(player.name)
                            }
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading) {
                            Spacer(minLength: 0)
                            ForEach(scoreBoard.away.players) { player in
                                Text(player.name)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .font(.system(size: 25))
                    ForEach(scoreBoard.score) { score in
                        VStack {
                            VStack {
                                Spacer(minLength: 0)
                                Text(String(score.home))
                                Spacer(minLength: 0)
                            }
                            VStack {
                                Spacer(minLength: 0)
                                Text(String(score.away))
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(width: 25)
                        .font(.system(size: 45))
                    }
                    Spacer()
                }
                .padding([.leading, .trailing], 3)
                .padding([.top], 3)
                .background(RgbColor(red: 0x0B, green: 0x10, blue: 0xAC).color())
                HStack {
                    Text("Powered by Moblin")
                        .fontDesign(.monospaced)
                        .font(.system(size: 15))
                        .bold()
                    Spacer()
                }
                .padding([.leading, .trailing], 3)
                .padding([.bottom], 3)
                .background(RgbColor(red: 0, green: 3, blue: 0x5B).color())
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
        guard let scoreBoard = scoreBoard.value else {
            return image
        }
        let scale = image.extent.height / 1080
        return scoreBoard
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(
                translationX: 10,
                y: image.extent.height - scoreBoard.extent.height - 10
            ))
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
