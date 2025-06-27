import Charts
import SwiftUI

private struct CollapsedBondingView: View {
    @ObservedObject var bonding: Bonding
    var color: Color

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "phone.connection")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundColor(color)
            if #available(iOS 17.0, *) {
                if !bonding.pieChartPercentages.isEmpty {
                    Chart(bonding.pieChartPercentages.reversed()) { item in
                        SectorMark(angle: .value("", item.percentage))
                            .foregroundStyle(item.color)
                    }
                    .chartLegend(.hidden)
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .padding([.trailing], 2)
                }
            }
        }
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct BondingStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var bonding: Bonding
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusBonding() {
            if textPlacement == .hide {
                CollapsedBondingView(
                    bonding: bonding,
                    color: netStreamColor(model: model)
                )
            } else {
                StreamOverlayIconAndTextView(
                    icon: "phone.connection",
                    text: bonding.statistics,
                    textPlacement: textPlacement,
                    color: netStreamColor(model: model)
                )
            }
        }
        if model.isShowingStatusBondingRtts() {
            StreamOverlayIconAndTextView(
                icon: "phone.connection",
                text: bonding.rtts,
                textPlacement: textPlacement,
                color: netStreamColor(model: model)
            )
        }
    }
}

private struct CollapsedHypeTrainView: View {
    var status: String
    var color: Color

    var body: some View {
        HStack(spacing: 1) {
            let train = Image(systemName: "train.side.front.car")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundColor(color)
            if #available(iOS 18.0, *) {
                train
                    .symbolEffect(
                        .wiggle.forward.byLayer,
                        options: .repeat(.periodic(delay: 2.0))
                    )
            } else {
                train
            }
            Text(status)
                .foregroundColor(.white)
                .padding([.leading, .trailing], 2)
        }
        .font(smallFont)
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct CollapsedAdsRemainingTimerView: View {
    @ObservedObject var status: Status

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "cup.and.saucer")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundColor(.white)
            Text(status.adsRemainingTimerStatus)
                .foregroundColor(.white)
                .padding([.leading, .trailing], 2)
        }
        .font(smallFont)
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct CollapsedBitrateView: View {
    @ObservedObject var bitrate: Bitrate

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "speedometer")
                .frame(width: 17, height: 17)
                .padding([.leading], 2)
                .foregroundColor(bitrate.statusColor)
                .background(bitrate.statusIconColor ?? .clear)
            if !bitrate.speedMbpsOneDecimal.isEmpty {
                Text(bitrate.speedMbpsOneDecimal)
                    .foregroundColor(.white)
                    .padding([.trailing], 2)
            }
        }
        .font(smallFont)
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct BitrateStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var bitrate: Bitrate
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if textPlacement == .hide {
            CollapsedBitrateView(bitrate: model.bitrate)
        } else {
            StreamOverlayIconAndTextView(
                icon: "speedometer",
                text: bitrate.speedAndTotal,
                textPlacement: textPlacement,
                color: bitrate.statusColor,
                iconBackgroundColor: bitrate.statusIconColor ?? backgroundColor
            )
        }
    }
}

private func netStreamColor(model: Model) -> Color {
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

private struct StreamUptimeStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var streamUptime: StreamUptimeProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "deskclock",
            text: streamUptime.uptime,
            textPlacement: textPlacement,
            color: netStreamColor(model: model)
        )
    }
}

private struct RecordingStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var recording: RecordingProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "record.circle",
            text: recording.length,
            textPlacement: textPlacement
        )
    }
}

private struct HypeTrainStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var hypeTrain: HypeTrain
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if textPlacement == .hide {
            CollapsedHypeTrainView(status: hypeTrain.status, color: .white)
        } else {
            StreamOverlayIconAndTextView(
                icon: "train.side.front.car",
                text: hypeTrain.status,
                textPlacement: textPlacement
            )
        }
    }
}

private struct MoblinkStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var moblink: Moblink
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func color() -> Color {
        if model.isMoblinkRelayConfigured() && !model.areMoblinkRelaysOk() {
            return .red
        }
        if !moblink.streamerOk {
            return .red
        }
        return .white
    }

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "app.connected.to.app.below.fill",
            text: moblink.status,
            textPlacement: textPlacement,
            color: color()
        )
    }
}

private struct ServersStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var servers: Servers
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "server.rack",
            text: servers.speedAndTotal,
            textPlacement: textPlacement
        )
    }
}

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: Status
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func remoteControlColor() -> Color {
        if model.isRemoteControlStreamerConfigured() && !model.isRemoteControlStreamerConnected() {
            return .red
        } else if model.isRemoteControlAssistantConfigured() && !model.isRemoteControlAssistantConnected() {
            return .red
        }
        return .white
    }

    private func djiDevicesColor() -> Color {
        return .white
    }

    private func catPrinterColor() -> Color {
        if model.isAnyCatPrinterConfigured() && !model.areAllCatPrintersConnected() {
            return .red
        }
        return .white
    }

    private func cyclingPowerDeviceColor() -> Color {
        if model.isAnyCyclingPowerDeviceConfigured() && !model.areAllCyclingPowerDevicesConnected() {
            return .red
        }
        return .white
    }

    private func heartRateDeviceColor() -> Color {
        if model.isAnyHeartRateDeviceConfigured() && !model.areAllHeartRateDevicesConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        if model.isShowingStatusHypeTrain() {
            HypeTrainStatusView(hypeTrain: model.hypeTrain, textPlacement: textPlacement)
        }
        if model.isShowingStatusAdsRemainingTimer() {
            if textPlacement == .hide {
                CollapsedAdsRemainingTimerView(status: status)
            } else {
                StreamOverlayIconAndTextView(
                    icon: "cup.and.saucer",
                    text: "\(status.adsRemainingTimerStatus) seconds",
                    textPlacement: textPlacement
                )
            }
        }
        if model.isShowingStatusServers() {
            ServersStatusView(servers: model.servers, textPlacement: textPlacement)
        }
        if model.isShowingStatusMoblink() {
            MoblinkStatusView(moblink: model.moblink, textPlacement: textPlacement)
        }
        if model.isShowingStatusRemoteControl() {
            StreamOverlayIconAndTextView(
                icon: "appletvremote.gen1",
                text: status.remoteControlStatus,
                textPlacement: textPlacement,
                color: remoteControlColor()
            )
        }
        if model.isShowingStatusDjiDevices() {
            StreamOverlayIconAndTextView(
                icon: "appletvremote.gen1",
                text: status.djiDevicesStatus,
                textPlacement: textPlacement,
                color: djiDevicesColor()
            )
        }
        if model.isShowingStatusGameController() {
            StreamOverlayIconAndTextView(
                icon: "gamecontroller",
                text: status.gameControllersTotal,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusBitrate() {
            BitrateStatusView(bitrate: model.bitrate, textPlacement: textPlacement)
        }
        BondingStatusView(bonding: model.bonding, textPlacement: textPlacement)
        if model.isShowingStatusReplay() {
            StreamOverlayIconAndTextView(
                icon: "play",
                text: String(localized: "Enabled"),
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusStreamUptime() {
            StreamUptimeStatusView(streamUptime: model.streamUptime, textPlacement: textPlacement)
        }
        if model.isShowingStatusLocation() {
            StreamOverlayIconAndTextView(
                icon: "location",
                text: model.location,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusRecording() {
            RecordingStatusView(recording: model.recording, textPlacement: textPlacement)
        }
        if model.isShowingStatusBrowserWidgets() {
            StreamOverlayIconAndTextView(
                icon: "globe",
                text: status.browserWidgetsStatus,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusCatPrinter() {
            StreamOverlayIconAndTextView(
                icon: "pawprint",
                text: status.catPrinterStatus,
                textPlacement: textPlacement,
                color: catPrinterColor()
            )
        }
        if model.isShowingStatusCyclingPowerDevice() {
            StreamOverlayIconAndTextView(
                icon: "bicycle",
                text: status.cyclingPowerDeviceStatus,
                textPlacement: textPlacement,
                color: cyclingPowerDeviceColor()
            )
        }
        if model.isShowingStatusHeartRateDevice() {
            StreamOverlayIconAndTextView(
                icon: "heart",
                text: status.heartRateDeviceStatus,
                textPlacement: textPlacement,
                color: heartRateDeviceColor()
            )
        }
        if model.isShowingStatusFixedHorizon() {
            StreamOverlayIconAndTextView(
                icon: "circle.and.line.horizontal",
                text: status.fixedHorizonStatus,
                textPlacement: textPlacement
            )
        }
        if status.phoneCoolerDeviceState == .connected {
            StreamOverlayIconAndTextView(
                icon: "fan",
                text: """
                \(String(status.phoneCoolerPhoneTemp ?? 0)) °C / \
                \(String(status.phoneCoolerExhaustTemp ?? 0)) °C
                """,
                textPlacement: .beforeIcon
            )
        }
    }
}

private struct AudioView: View {
    @ObservedObject var audio: AudioProvider

    var body: some View {
        if audio.showing {
            AudioLevelView(level: audio.level, channels: audio.numberOfChannels)
                .padding(20)
                .contentShape(Rectangle())
                .padding(-20)
        }
    }
}

struct RightOverlayTopView: View {
    var model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            VStack(alignment: .trailing, spacing: 1) {
                AudioView(audio: model.audio)
                if database.verboseStatuses {
                    StatusesView(show: database.show, status: model.status, textPlacement: .beforeIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(show: database.show, status: model.status, textPlacement: .hide)
                    }
                }
            }
            .onTapGesture {
                model.toggleVerboseStatuses()
            }
            Spacer()
        }
    }
}

struct RightOverlayBottomView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: SettingsShow
    let width: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Spacer()
            if !(model.showDrawOnStream || model.showFace) {
                if model.showingReplay {
                    StreamOverlayRightReplayView(replay: model.replay)
                } else {
                    if model.showMediaPlayerControls {
                        StreamOverlayRightMediaPlayerControlsView(mediaPlayer: model.mediaPlayerPlayer)
                    } else {
                        if model.showingPixellate {
                            StreamOverlayRightPixellateView(database: model.database)
                        }
                        if model.showingWhirlpool {
                            StreamOverlayRightWhirlpoolView(database: model.database)
                        }
                        if model.showingPinch {
                            StreamOverlayRightPinchView(database: model.database)
                        }
                        if model.showingCamera {
                            StreamOverlayRightCameraSettingsControlView()
                        }
                        if show.zoomPresets && model.hasZoom {
                            StreamOverlayRightZoomPresetSelctorView(database: model.database,
                                                                    zoom: model.zoom,
                                                                    width: width)
                        }
                    }
                    StreamOverlayRightSceneSelectorView(database: model.database, width: width)
                }
            }
        }
    }
}
