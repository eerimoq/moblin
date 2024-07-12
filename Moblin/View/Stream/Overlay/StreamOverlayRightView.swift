import SwiftUI

struct RightOverlayView: View {
    @EnvironmentObject var model: Model
    let width: CGFloat

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
                show: model.isShowingStatusServers(),
                icon: "server.rack",
                text: model.serversSpeedAndTotal,
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
                show: model.isShowingStatusBonding(),
                icon: "phone.connection",
                text: model.bondingStatistics,
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
            if !(model.showDrawOnStream || model.showFace) {
                if model.showMediaPlayerControls {
                    StreamOverlayRightMediaPlayerControlsView()
                } else {
                    if model.showingCamera {
                        StreamOverlayRightCameraSettingsControlView()
                    }
                    if database.show.zoomPresets && model.hasZoom {
                        StreamOverlayRightZoomPresetSelctorView(width: width)
                    }
                }
                StreamOverlayRightSceneSelectorView(width: width)
            }
        }
    }
}
