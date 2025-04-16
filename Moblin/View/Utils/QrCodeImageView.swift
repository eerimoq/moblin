import SwiftUI

struct QrCodeImageView: View {
    var image: UIImage
    var height: Double

    var body: some View {
        HStack {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxHeight: height)
            Spacer()
        }
    }
}
