import SwiftUI

struct ControlBarBackgroundView: View {
    @ObservedObject var controlBar: ControlBar

    var body: some View {
        Color.black
            .overlay {
                if let image = controlBar.backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(controlBar.backgroundImageOpacity)
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}
