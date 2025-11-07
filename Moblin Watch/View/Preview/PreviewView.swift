import SwiftUI

private struct AudioLevelView: View {
    let level: Float

    var body: some View {
        if level.isNaN {
            CompactAudioLevelIconView(
                name: "microphone.slash",
                foregroundColor: .white,
                backgroundColor: backgroundColor
            )
        } else {
            let (foregroundColor, backgroundColor) = compactAudioLevelColors(level: level)
            CompactAudioLevelIconView(
                name: "waveform",
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
        }
    }
}

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preview: Preview
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusThermalState() {
            Image(systemName: "flame")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(preview.thermalState.color())
                .background(backgroundColor)
                .cornerRadius(5)
        }
        if model.isShowingWorkout() {
            StreamOverlayIconAndTextView(
                icon: "figure.run",
                text: preview.workoutType,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusBitrate() {
            StreamOverlayIconAndTextView(
                icon: "speedometer",
                text: preview.speedAndTotal,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusRecording() {
            StreamOverlayIconAndTextView(
                icon: "record.circle",
                text: preview.recordingLength,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusAudioLevel() {
            AudioLevelView(level: preview.audioLevel)
        }
    }
}

class Preview: ObservableObject {
    @Published var speedAndTotal = noValue
    @Published var recordingLength = noValue
    @Published var thermalState = ProcessInfo.ThermalState.nominal
    @Published var workoutType = noValue
    @Published var image: UIImage?
    @Published var showPreviewDisconnected = true
    @Published var viewerCount = noValue
    @Published var zoomX = 0.0
    @Published var isZooming = false
    @Published var verboseStatuses = false
    @Published var zoomPresetIdPicker: UUID?
    @Published var zoomPresetId: UUID = .init()
    @Published var zoomPresets: [WatchProtocolZoomPreset] = []
    @Published var scenes: [WatchProtocolScene] = []
    @Published var sceneId: UUID = .init()
    @Published var sceneIdPicker: UUID = .init()
    @Published var audioLevel: Float = defaultAudioLevel
}

struct PreviewView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preview: Preview

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let image = preview.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                if preview.showPreviewDisconnected {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "cable.connector.slash")
                                .font(.title)
                                .padding(5)
                                .foregroundStyle(.white)
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
                        if !model.viaRemoteControl, preview.viewerCount != noValue {
                            StreamOverlayIconAndTextView(
                                icon: "eye",
                                text: preview.viewerCount,
                                textPlacement: .afterIcon
                            )
                        }
                        StreamOverlayIconAndTextView(
                            icon: "magnifyingglass",
                            text: String(format: "%.1f", preview.zoomX),
                            textPlacement: .afterIcon
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Spacer()
                        if preview.verboseStatuses {
                            StatusesView(preview: preview, textPlacement: .beforeIcon)
                        } else {
                            HStack(spacing: 1) {
                                StatusesView(preview: preview, textPlacement: .hide)
                            }
                        }
                    }
                    .onTapGesture {
                        preview.verboseStatuses.toggle()
                    }
                }
                .focusable(true)
                .digitalCrownRotation(detent: $preview.zoomX,
                                      from: 0.5,
                                      through: 10,
                                      by: 0.1,
                                      sensitivity: .low,
                                      isContinuous: false,
                                      isHapticFeedbackEnabled: true)
                { _ in
                    preview.isZooming = true
                } onIdle: {
                    preview.isZooming = false
                    model.setZoom(x: preview.zoomX)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
            .padding([.bottom], 3)
            List {
                if !model.viaRemoteControl {
                    Picker(selection: $preview.zoomPresetIdPicker) {
                        ForEach(preview.zoomPresets) { zoomPreset in
                            Text(zoomPreset.name)
                                .tag(zoomPreset.id as UUID?)
                        }
                        .onChange(of: preview.zoomPresetIdPicker) { _, _ in
                            guard preview.zoomPresetIdPicker != preview.zoomPresetId else {
                                return
                            }
                            model.setZoomPreset(id: preview.zoomPresetIdPicker ?? .init())
                        }
                        Text("Other")
                            .tag(nil as UUID?)
                    } label: {
                        Text("Zoom")
                    }
                }
                if preview.scenes.contains(where: { preview.sceneIdPicker == $0.id }) {
                    Picker(selection: $preview.sceneIdPicker) {
                        ForEach(preview.scenes) { scene in
                            Text(scene.name)
                        }
                        .onChange(of: preview.sceneIdPicker) { _, _ in
                            guard preview.sceneIdPicker != preview.sceneId else {
                                return
                            }
                            model.setScene(id: preview.sceneIdPicker)
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
