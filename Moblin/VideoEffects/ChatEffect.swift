import SwiftUI

final class ChatEffect: VideoEffect {
    private var chatImage: CIImage?

    override func getName() -> String {
        return "chat"
    }

    @MainActor
    func update() {
        let chat = VStack {
            Text("Test")
        }
        .font(.system(size: 50))
        .foregroundStyle(.white)
        .background(.black)
        let renderer = ImageRenderer(content: chat)
        guard let uiImage = renderer.uiImage else {
            return
        }
        setChatImage(image: CIImage(image: uiImage))
    }

    private func setChatImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.chatImage = image
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return chatImage?.composited(over: image) ?? image
    }
}
