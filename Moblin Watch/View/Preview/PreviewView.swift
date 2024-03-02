import SwiftUI

struct PreviewView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            if let preview = model.preview {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding([.bottom], 3)
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "tv.slash")
                        Spacer()
                    }
                    Spacer()
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding([.bottom], 3)
            }
            VStack(spacing: 1) {
                Spacer()
                HStack {
                    Spacer()
                    AudioLevelView(showBar: true, level: model.audioLevel)
                }
                HStack {
                    Spacer()
                    StreamOverlayIconAndTextView(
                        show: true,
                        icon: "speedometer",
                        text: model.speedAndTotal,
                        textFirst: true
                    )
                }
                .padding([.bottom], 4)
            }
            .padding([.leading], 3)
        }
    }
}
