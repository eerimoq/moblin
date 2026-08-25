import Combine
import MetalPetal
import SwiftUI

private let borderWidth = 1.5

private class EmoteComboState: ObservableObject {
    @Published var emoteUrl: URL?
    @Published var count: Int = 0
}

private struct EmoteComboView: View {
    @ObservedObject var state: EmoteComboState
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let canvasSize: CGSize

    private func widgetSize() -> Double {
        toPixels(sceneWidget.layout.size, canvasSize.minimum())
    }

    var body: some View {
        if let url = state.emoteUrl {
            let size = widgetSize()
            HStack(spacing: size * 0.15) {
                CacheAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    EmptyView()
                }
                .frame(width: size, height: size)
                Text("x\(state.count) combo!")
                    .font(.system(size: size / 2, weight: .bold))
                    .foregroundStyle(.white)
                    .stroke(color: .black, width: borderWidth)
            }
        }
    }
}

final class ChatEmoteComboEffect: VideoEffect, @unchecked Sendable {
    private let canvasSize: CGSize
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var sceneWidgetPipeline = SettingsSceneWidget(widgetId: .init())
    private var comboImage: EffectImageCgImage?
    private var renderer: ImageRenderer<EmoteComboView>?
    private var cancellable: AnyCancellable?
    private let state = EmoteComboState()
    private var settings = SettingsWidgetChatEmoteCombo()
    private var currentEmoteUrl: URL?
    private var comboCount: Int = 0
    private let timer = SimpleTimer(queue: .main)

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init()
    }

    @MainActor
    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
        self.sceneWidget.layout = sceneWidget.layout
    }

    @MainActor
    func setSettings(settings: SettingsWidgetChatEmoteCombo) {
        guard settings !== self.settings else {
            return
        }
        self.settings = settings
        setup()
    }

    @MainActor
    func appendMessage(post: ChatPost) {
        guard let emoteUrl = post.segments.first?.url else {
            return
        }
        if emoteUrl == currentEmoteUrl {
            comboCount += 1
        } else {
            currentEmoteUrl = emoteUrl
            comboCount = 1
        }
        if comboCount >= settings.minimumCombo {
            state.emoteUrl = emoteUrl
            state.count = comboCount
        }
        timer.startSingleShot(timeout: Double(settings.resetAfter)) {
            self.currentEmoteUrl = nil
            self.comboCount = 0
            self.setComboImage(image: nil)
        }
    }

    @MainActor
    private func setup() {
        cancellable?.cancel()
        renderer = ImageRenderer(content: EmoteComboView(state: state,
                                                         sceneWidget: sceneWidget,
                                                         canvasSize: canvasSize))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            let image = renderer?.cgImage
            if comboCount > 0 {
                setComboImage(image: image)
            }
        }
        _ = renderer?.cgImage
        setComboImage(image: nil)
    }

    private func setComboImage(image: CGImage?) {
        let comboImage = image?.toEffectImage()
        processorPipelineQueue.async {
            self.comboImage = comboImage
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let comboImage else {
            return image
        }
        return comboImage.getCiImage()
            .move(sceneWidgetPipeline.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        comboImage?.getMetalPetalImage().moveComposited(sceneWidgetPipeline.layout, image) ?? image
    }
}
