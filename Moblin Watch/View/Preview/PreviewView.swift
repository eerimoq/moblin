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
            }
            if model.showPreviewDisconnected {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "cable.connector.slash")
                            .font(.title)
                            .padding(5)
                            .foregroundColor(.white)
                            .background(Color(white: 0, opacity: 0.6))
                            .cornerRadius(5)
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
                    ThermalStateView(thermalState: model.thermalState)
                }
                .padding([.bottom], 4)
                .padding([.trailing], 5)
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
