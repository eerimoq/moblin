import SwiftUI

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    var textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusThermalState() {
            Image(systemName: "flame")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundColor(model.thermalState.color())
                .background(backgroundColor)
                .cornerRadius(5)
        }
        StreamOverlayIconAndTextView(
            show: model.isShowingWorkout(),
            icon: "figure.run",
            text: model.workoutType,
            textPlacement: textPlacement
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusBitrate(),
            icon: "speedometer",
            text: model.speedAndTotal,
            textPlacement: textPlacement
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusRecording(),
            icon: "record.circle",
            text: model.recordingLength,
            textPlacement: textPlacement
        )
    }
}

struct PreviewView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(spacing: 0) {
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
                    VStack(alignment: .leading, spacing: 1) {
                        Spacer()
                        if !model.viaRemoteControl {
                            StreamOverlayIconAndTextView(
                                show: model.viewerCount != noValue,
                                icon: "eye",
                                text: model.viewerCount,
                                textPlacement: .afterIcon
                            )
                        }
                        StreamOverlayIconAndTextView(
                            show: true,
                            icon: "magnifyingglass",
                            text: String(format: "%.1f", model.zoomX),
                            textPlacement: .afterIcon
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Spacer()
                        if model.verboseStatuses {
                            StatusesView(textPlacement: .beforeIcon)
                        } else {
                            HStack(spacing: 1) {
                                StatusesView(textPlacement: .hide)
                            }
                        }
                        if model.isShowingStatusAudioLevel() {
                            AudioLevelView(level: model.audioLevel)
                        }
                    }
                    .onTapGesture {
                        model.verboseStatuses.toggle()
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
            .padding([.bottom], 3)
            List {
                if !model.viaRemoteControl {
                    Picker(selection: $model.zoomPresetIdPicker) {
                        ForEach(model.zoomPresets) { zoomPreset in
                            Text(zoomPreset.name)
                                .tag(zoomPreset.id as UUID?)
                        }
                        .onChange(of: model.zoomPresetIdPicker) { _, _ in
                            guard model.zoomPresetIdPicker != model.zoomPresetId else {
                                return
                            }
                            model.setZoomPreset(id: model.zoomPresetIdPicker ?? .init())
                        }
                        Text("Other")
                            .tag(nil as UUID?)
                    } label: {
                        Text("Zoom")
                    }
                }
                if model.scenes.contains(where: { model.sceneIdPicker == $0.id }) {
                    Picker(selection: $model.sceneIdPicker) {
                        ForEach(model.scenes) { scene in
                            Text(scene.name)
                        }
                        .onChange(of: model.sceneIdPicker) { _, _ in
                            guard model.sceneIdPicker != model.sceneId else {
                                return
                            }
                            model.setScene(id: model.sceneIdPicker)
                        }
                    } label: {
                        Text("Scene")
                    }
                }
            }
            .scrollDisabled(true)
            Spacer()
        }
        .ignoresSafeArea()
    }
}
