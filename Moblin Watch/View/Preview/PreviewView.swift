import SwiftUI

struct PreviewView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack {
            ZStack {
                if let preview = model.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
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
                                .background(backgroundColor)
                                .cornerRadius(5)
                            Spacer()
                        }
                        Spacer()
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                }
                HStack {
                    VStack(alignment: .trailing, spacing: 1) {
                        Spacer()
                        StreamOverlayIconAndTextView(
                            show: true,
                            icon: "magnifyingglass",
                            text: String(format: "%.1f", model.zoomX),
                            textFirst: false
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Spacer()
                        if model.isShowingStatusThermalState() {
                            Image(systemName: "flame")
                                .frame(width: 17, height: 17)
                                .font(smallFont)
                                .padding([.leading, .trailing], 2)
                                .foregroundColor(model.thermalState.color())
                                .background(backgroundColor)
                                .cornerRadius(5)
                        }
                        if model.isShowingStatusAudioLevel() {
                            AudioLevelView(showBar: true, level: model.audioLevel)
                        }
                        StreamOverlayIconAndTextView(
                            show: model.isShowingStatusBitrate(),
                            icon: "speedometer",
                            text: model.speedAndTotal,
                            textFirst: true
                        )
                        StreamOverlayIconAndTextView(
                            show: model.isShowingStatusRecording(),
                            icon: "record.circle",
                            text: model.recordingLength,
                            textFirst: true
                        )
                    }
                }
                .focusable(true)
                .digitalCrownRotation(detent: $model.zoomX,
                                      from: 0.5,
                                      through: 10,
                                      by: 0.1,
                                      sensitivity: .low,
                                      isContinuous: false,
                                      isHapticFeedbackEnabled: true)
                { _ in
                    model.isZooming = true
                } onIdle: {
                    model.isZooming = false
                    model.setZoom(x: model.zoomX)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .ignoresSafeArea()
    }
}
