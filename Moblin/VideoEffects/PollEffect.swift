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
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
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
        let overlay = image.map { moveToTopRight(image: CIImage(cgImage: $0), size: state.size) }
        let overlayMetalPetal = image.map { MTIImage(cgImage: $0) }
        processorPipelineQueue.async {
            self.overlay = overlay
            self.overlayMetalPetal = overlayMetalPetal
        }
    }

    private func moveToTopRight(image: CIImage, size: CGSize) -> CIImage {
        let x = size.width - image.extent.width
        return image
            .translated(x: x - 5, y: size.height - image.extent.height - 5)
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard let overlayMetalPetal else {
            return image
        }
        let size = overlayMetalPetal.extent.size
        let position = CGPoint(x: image.extent.width - size.width / 2 - 5, y: size.height / 2 + 5)
        return overlayMetalPetal.positionComposited(position, image)
    }
}
