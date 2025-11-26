import AVFoundation
import Combine
import SwiftUI
import UIKit
import Vision

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
        return 30 * (size.maximum() / 1920)
    }

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
            Text(state.text)
        }
        .padding([.trailing], 7)
        .background(.black.opacity(0.75))
        .foregroundStyle(.white)
        .font(.system(size: scaledFontSize(size: state.size)))
        .cornerRadius(10)
    }
}

final class PollEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
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

    override func getName() -> String {
        return "Poll widget"
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
            self.setOverlay(image: self.renderer?.ciImage())
        }
        setOverlay(image: renderer?.ciImage())
    }

    private func setOverlay(image: CIImage?) {
        let overlay: CIImage?
        if let image {
            overlay = moveToTopRight(image: image, size: state.size)
        } else {
            overlay = nil
        }
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
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
