import SwiftUI

struct RightOverlayView: View {
    @EnvironmentObject var model: Model

    private var database: Database {
        model.settings.database
    }

    private func netStreamColor() -> Color {
        if model.isStreaming() {
            switch model.streamState {
            case .connecting:
                return .white
            case .connected:
                return .white
            case .disconnected:
                return .red
            }
        } else {
            return .white
        }
    }

    private func remoteControlColor() -> Color {
        if model.isRemoteControlStreamerConfigured() && !model.isRemoteControlStreamerConnected() {
            return .red
        } else if model.isRemoteControlAssistantConfigured() && !model.isRemoteControlAssistantConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.isShowingStatusAudioLevel() {
                AudioLevelView(
                    showBar: database.show.audioBar,
                    level: model.audioLevel,
                    channels: model.numberOfAudioChannels
                )
            }
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRtmpServer(),
                icon: "server.rack",
                text: model.rtmpSpeedAndTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRemoteControl(),
                icon: "appletvremote.gen1",
                text: model.remoteControlStatus,
                textFirst: true,
                color: remoteControlColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusGameController(),
                icon: "gamecontroller",
                text: model.gameControllersTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBitrate(),
                icon: "speedometer",
                text: model.speedAndTotal,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusUptime(),
                icon: "deskclock",
                text: model.uptime,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusLocation(),
                icon: "location",
                text: model.location,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusSrtla(),
                icon: "phone.connection",
                text: model.srtlaConnectionStatistics,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRecording(),
                icon: "record.circle",
                text: model.recordingLength,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBrowserWidgets(),
                icon: "globe",
                text: model.browserWidgetsStatus,
                textFirst: true,
                color: .white
            )
            Spacer()
            if !model.showDrawOnStream {
                if database.show.zoomPresets && model.hasZoom {
                    if model.cameraPosition == .front {
                        Picker("", selection: $model.frontZoomPresetId) {
                            ForEach(database.zoom.front) { preset in
                                Text(preset.name)
                                    .tag(preset.id)
                            }
                        }
                        .onChange(of: model.frontZoomPresetId) { id in
                            model.setCameraZoomPreset(id: id)
                        }
                        .pickerStyle(.segmented)
                        .padding([.bottom], 1)
                        .background(Color(uiColor: .systemBackground).opacity(0.8))
                        .frame(width: CGFloat(50 * database.zoom.front.count))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(.secondary)
                        )
                        .padding([.bottom], 5)
                    } else {
                        Picker("", selection: $model.backZoomPresetId) {
                            ForEach(model.backZoomPresets()) { preset in
                                Text(preset.name)
                                    .tag(preset.id)
                            }
                        }
                        .onChange(of: model.backZoomPresetId) { id in
                            model.setCameraZoomPreset(id: id)
                        }
                        .pickerStyle(.segmented)
                        .padding([.bottom], 1)
                        .background(Color(uiColor: .systemBackground).opacity(0.8))
                        .frame(width: CGFloat(50 * model.backZoomPresets().count))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(.secondary)
                        )
                        .padding([.bottom], 5)
                    }
                }
                Picker("", selection: $model.sceneIndex) {
                    ForEach(0 ..< model.enabledScenes.count, id: \.self) { id in
                        let scene = model.enabledScenes[id]
                        Text(scene.name)
                            .tag(scene.id)
                    }
                }
                .onChange(of: model.sceneIndex) { tag in
                    model.setSceneId(id: model.enabledScenes[tag].id)
                    model.sceneUpdated(store: false, scrollQuickButtons: true)
                }
                .pickerStyle(.segmented)
                .padding([.bottom], 1)
                .background(Color(uiColor: .systemBackground).opacity(0.8))
                .frame(width: CGFloat(70 * model.enabledScenes.count))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.secondary)
                )
            }
        }
    }
}
