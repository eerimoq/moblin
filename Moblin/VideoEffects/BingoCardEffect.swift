import Combine
import SwiftUI

private struct BingoView: View {
    @ObservedObject var settings: SettingsWidgetBingoCard
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let canvasSize: CGSize

    private func squareSize(squaresCountSide: Int) -> Double {
        return toPixels(sceneWidget.layout.size, canvasSize.minimum()) / Double(squaresCountSide)
    }

    var body: some View {
        let squaresCountSide = settings.size()
        let squareSize = squareSize(squaresCountSide: squaresCountSide)
        ZStack {
            VStack(spacing: 0) {
                ForEach(0 ..< squaresCountSide, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0 ..< squaresCountSide, id: \.self) { column in
                            ZStack {
                                Rectangle()
                                    .stroke(settings.foregroundColorColor, lineWidth: 2)
                                    .background(settings.backgroundColorColor)
                                let index = row * squaresCountSide + column
                                if index < settings.squares.count {
                                    let square = settings.squares[index]
                                    Text(square.text)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.4)
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 35 * squareSize / 100))
                                        .padding(4)
                                    if square.checked {
                                        Text(String("╳"))
                                            .font(.system(size: 80 * squareSize / 100))
                                    }
                                }
                            }
                            .frame(width: squareSize, height: squareSize)
                        }
                    }
                }
            }
            .padding(1)
            Rectangle()
                .stroke(settings.foregroundColorColor, lineWidth: 1)
                .background(.clear)
        }
        .foregroundStyle(settings.foregroundColorColor)
    }
}

final class BingoCardEffect: VideoEffect {
    private let canvasSize: CGSize
    private var settings = SettingsWidgetBingoCard()
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var sceneWidgetPipeline = SettingsSceneWidget(widgetId: .init())
    private var renderer: ImageRenderer<BingoView>?
    private var cancellable: AnyCancellable?
    private var bingoImage: CIImage?

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init()
        DispatchQueue.main.async {
            self.setup()
        }
    }

    override func getName() -> String {
        return "Bingo card"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        self.sceneWidget.layout = sceneWidget.layout
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
    }

    func setSettings(settings: SettingsWidgetBingoCard) {
        self.settings.update(other: settings)
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return bingoImage?
            .move(sceneWidgetPipeline.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    @MainActor
    private func setup() {
        renderer = ImageRenderer(content: BingoView(settings: settings,
                                                    sceneWidget: sceneWidget,
                                                    canvasSize: canvasSize))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            self.setBingoImage(image: self.renderer?.ciImage())
        }
        setBingoImage(image: renderer?.ciImage())
    }

    private func setBingoImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.bingoImage = image
        }
    }
}
