import SwiftUI

struct QrCodeImageView: View {
    let image: UIImage
    let height: Double
    @State var isFullScreen = false

    var body: some View {
        HCenter {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxHeight: height)
                Text("Tap the QR code for full screen")
                    .padding([.bottom], 7)
            }
        }
        .onTapGesture {
            isFullScreen = true
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            Button {
                isFullScreen = false
            } label: {
                HCenter {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                }
                .background(.white)
            }
        }
    }
}
