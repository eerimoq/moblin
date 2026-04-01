import SwiftUI

private let talkBackVideoWidth: CGFloat = 250
private let talkBackCiContext = CIContext()

struct TalkBackVideoView: View {
    let model: Model
    @State private var image: UIImage?
    private let timer = Timer.publish(every: 1 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: talkBackVideoWidth)
                    .cornerRadius(7)
                    .padding([.bottom], 5)
            }
        }
        .onReceive(timer) { _ in
            updateImage()
        }
    }

    private func updateImage() {
        let id = model.database.talkBack.videoSourceId
        guard let pixelBuffer = model.media.getTalkBackVideoPixelBuffer(id) else {
            return
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = talkBackCiContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        image = UIImage(cgImage: cgImage)
    }
}
