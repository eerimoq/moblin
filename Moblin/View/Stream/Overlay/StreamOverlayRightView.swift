import SwiftUI

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    let textPlacement: StreamOverlayIconAndTextPlacement

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
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusServers(),
            icon: "server.rack",
            text: model.serversSpeedAndTotal,
            textPlacement: textPlacement,
            color: .white
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusRemoteControl(),
            icon: "appletvremote.gen1",
            text: model.remoteControlStatus,
            textPlacement: textPlacement,
            color: remoteControlColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusGameController(),
            icon: "gamecontroller",
            text: model.gameControllersTotal,
            textPlacement: textPlacement,
            color: .white
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusBitrate(),
            icon: "speedometer",
            text: model.speedAndTotal,
            textPlacement: textPlacement,
            color: netStreamColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusUptime(),
            icon: "deskclock",
            text: model.uptime,
            textPlacement: textPlacement,
            color: netStreamColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusLocation(),
            icon: "location",
            text: model.location,
            textPlacement: textPlacement,
            color: .white
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusBonding(),
            icon: "phone.connection",
            text: model.bondingStatistics,
            textPlacement: textPlacement,
            color: netStreamColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusRecording(),
            icon: "record.circle",
            text: model.recordingLength,
            textPlacement: textPlacement,
            color: .white
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusBrowserWidgets(),
            icon: "globe",
            text: model.browserWidgetsStatus,
            textPlacement: textPlacement,
            color: .white
        )
    }
}

struct RightOverlayView: View {
    @EnvironmentObject var model: Model
    let width: CGFloat

    private var database: Database {
        model.settings.database
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            VStack(alignment: .trailing, spacing: 1) {
                if model.isShowingStatusAudioLevel() {
                    AudioLevelView(
                        showBar: database.show.audioBar,
                        level: model.audioLevel,
                        channels: model.numberOfAudioChannels
                    )
                }
                if model.verboseStatuses {
                    StatusesView(textPlacement: .beforeIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(textPlacement: .hide)
                    }
                }
            }
            .onTapGesture {
                model.verboseStatuses.toggle()
            }
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
