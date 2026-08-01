import Combine
import MetalPetal
import SwiftUI

private class PollState: ObservableObject {
    let size: CGSize
    @Published var text = String(localized: "No votes yet")

    init(size: CGSize) {
        self.size = size
    }
}

private struct PollView: View {
    @ObservedObject var state: PollState

    private func scaledFontSize(size: CGSize) -> CGFloat {
        30 * (size.maximum() / 1920)
    }

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
            Text(state.text)
        }
        .padding(.trailing, 7)
        .background(.black.opacity(0.75))
        .foregroundStyle(.white)
        .font(.system(size: scaledFontSize(size: state.size)))
        .cornerRadius(10)
    }
}

final class PollEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: EffectImageCgImage?
    private var renderer: ImageRenderer<PollView>?
    private var cancellable: AnyCancellable?
    private let state: PollState

    init(canvasSize: CGSize) {
        state = PollState(size: canvasSize)
        super.init()
        DispatchQueue.main.async {
            self.setup()
        }
    }

    func updateText(text: String) {
        guard state.text != text else {
            return
        }
        state.text = text
    }

    @MainActor
    private func setup() {
        renderer = ImageRenderer(content: PollView(state: state))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            setOverlay(image: renderer?.cgImage)
        }
        setOverlay(image: renderer?.cgImage)
    }

    private func setOverlay(image: CGImage?) {
        let overlay = image?.toEffectImage()
        processorPipelineQueue.async {
            self.overlay = overlay
        }
    }

    private func moveToTopRight(image: CIImage, size: CGSize) -> CIImage {
        let x = size.width - image.extent.width
        return image
            .translated(x: x - 5, y: size.height - image.extent.height - 5)
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let overlay else {
            return image
        }
        filter.inputImage = moveToTopRight(image: overlay.getCiImage(), size: image.extent.size)
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard let overlay = overlay?.getMetalPetalImage() else {
            return image
        }
        let size = overlay.extent.size
        let position = CGPoint(x: image.extent.width - size.width / 2 - 5, y: size.height / 2 + 5)
        return overlay.positionComposited(position, image)
    }
}
