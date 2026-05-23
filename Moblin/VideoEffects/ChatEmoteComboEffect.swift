import Combine
import SwiftUI

private let borderWidth = 1.5

private class EmoteComboState: ObservableObject {
    @Published var emoteUrl: URL?
    @Published var count: Int = 0
    @Published var visible: Bool = false
}

private struct EmoteComboView: View {
    @ObservedObject var state: EmoteComboState
    @ObservedObject var settings: SettingsWidgetChatEmoteCombo

    private func emoteSize() -> CGFloat {
        CGFloat(settings.fontSize) * 3.5
    }

    private func countFontSize() -> CGFloat {
        CGFloat(settings.fontSize)
    }

    var body: some View {
        if state.visible, let url = state.emoteUrl {
            VStack(spacing: 4) {
                CacheAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    EmptyView()
                }
                .frame(width: emoteSize(), height: emoteSize())
                Text("x\(state.count)")
                    .font(.system(size: countFontSize(), weight: .bold))
                    .foregroundStyle(.white)
                    .stroke(color: .black, width: borderWidth)
            }
        }
    }
}

final class ChatEmoteComboEffect: VideoEffect, @unchecked Sendable {
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var comboImage: CIImage?
    private var renderer: ImageRenderer<EmoteComboView>?
    private var cancellable: AnyCancellable?
    private var started: Bool = false
    private let state = EmoteComboState()
    private var settings = SettingsWidgetChatEmoteCombo()
    private var currentEmoteUrl: URL?
    private var comboCount: Int = 0
    private var hideWorkItem: DispatchWorkItem?

    func start() {
        guard !started else {
            return
        }
        started = true
        DispatchQueue.main.async {
            self.startInternal()
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        DispatchQueue.main.async {
            self.stopInternal()
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: SettingsWidgetChatEmoteCombo) {
        DispatchQueue.main.async {
            self.settings.fontSize = settings.fontSize
            self.settings.minCombo = settings.minCombo
            self.settings.resetAfterSeconds = settings.resetAfterSeconds
        }
    }

    func appendMessage(post: ChatPost) {
        guard let emoteUrl = post.segments.first(where: { $0.url != nil })?.url else {
            return
        }
        DispatchQueue.main.async {
            self.processEmote(url: emoteUrl)
        }
    }

    @MainActor
    private func processEmote(url: URL) {
        hideWorkItem?.cancel()
        if url == currentEmoteUrl {
            comboCount += 1
        } else {
            currentEmoteUrl = url
            comboCount = 1
        }
        if comboCount >= settings.minCombo {
            state.emoteUrl = url
            state.count = comboCount
            state.visible = true
        }
        let resetAfter = settings.resetAfterSeconds
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            state.visible = false
            currentEmoteUrl = nil
            comboCount = 0
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(Int(resetAfter * 1000)),
            execute: workItem
        )
    }

    @MainActor
    private func startInternal() {
        renderer = ImageRenderer(content: EmoteComboView(state: state, settings: settings))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            setComboImage(image: renderer?.ciImage())
        }
        setComboImage(image: renderer?.ciImage())
    }

    @MainActor
    private func stopInternal() {
        hideWorkItem?.cancel()
        state.visible = false
        currentEmoteUrl = nil
        comboCount = 0
        renderer = nil
        cancellable = nil
    }

    private func setComboImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.comboImage = image
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let comboImage else {
            return image
        }
        return comboImage
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }
}
