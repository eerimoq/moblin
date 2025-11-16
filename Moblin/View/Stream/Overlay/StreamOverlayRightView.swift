import Charts
import SwiftUI

private struct CollapsedBondingView: View {
    @ObservedObject var bonding: Bonding
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "phone.connection")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(color)
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
    // To trigger updates.
    @ObservedObject var show: SettingsShow
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

private struct ReplayStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var replay: SettingsStreamReplay
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusReplay() {
            StreamOverlayIconAndTextView(
                icon: "play",
                text: String(localized: "Enabled"),
                textPlacement: textPlacement
            )
        }
    }
}

private struct CollapsedHypeTrainView: View {
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            let train = Image(systemName: "train.side.front.car")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(color)
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
                .foregroundStyle(.white)
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
    @ObservedObject var status: StatusTopRight

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "cup.and.saucer")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(.white)
            Text(status.adsRemainingTimerStatus)
                .foregroundStyle(.white)
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

private struct AdsRemainingTimerView: View {
    let model: Model
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
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
    }
}

private struct CollapsedBitrateView: View {
    @ObservedObject var bitrate: Bitrate

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "speedometer")
                .frame(width: 17, height: 17)
                .padding([.leading], 2)
                .foregroundStyle(bitrate.statusColor)
                .background(bitrate.statusIconColor ?? .clear)
            if !bitrate.speedMbpsOneDecimal.isEmpty {
                Text(bitrate.speedMbpsOneDecimal)
                    .foregroundStyle(.white)
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
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var bitrate: Bitrate
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusBitrate() {
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
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var streamUptime: StreamUptimeProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusStreamUptime() {
            StreamOverlayIconAndTextView(
                icon: "deskclock",
                text: streamUptime.uptime,
                textPlacement: textPlacement,
                color: netStreamColor(model: model)
            )
        }
    }
}

private struct CpuStatusView: View {
    let model: Model
    @ObservedObject var show: SettingsShow
    @ObservedObject var systemMonitor: SystemMonitor
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusCpu() {
            if textPlacement == .hide {
                HStack(spacing: 1) {
                    Image(systemName: "cpu")
                        .frame(width: 17, height: 17)
                        .padding([.leading], 2)
                        .foregroundStyle(.white)
                    Text(systemMonitor.formatShort())
                        .foregroundStyle(.white)
                        .padding([.trailing], 2)
                }
                .font(smallFont)
                .background(backgroundColor)
                .cornerRadius(5)
                .padding(20)
                .contentShape(Rectangle())
                .padding(-20)
            } else {
                StreamOverlayIconAndTextView(
                    icon: "cpu",
                    text: systemMonitor.format(),
                    textPlacement: textPlacement
                )
            }
        }
    }
}

private struct HypeTrainStatusView: View {
    let model: Model
    @ObservedObject var hypeTrain: HypeTrain
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusHypeTrain() {
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
}

private struct MoblinkStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var moblink: Moblink
    // To trigger updates.
    @ObservedObject var streamer: SettingsMoblinkStreamer
    // To trigger updates.
    @ObservedObject var relay: SettingsMoblinkRelay
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
        if model.isShowingStatusMoblink() {
            StreamOverlayIconAndTextView(
                icon: "app.connected.to.app.below.fill",
                text: moblink.status,
                textPlacement: textPlacement,
                color: color()
            )
        }
    }
}

private struct RemoteControlStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    // To trigger updates.
    @ObservedObject var streamer: SettingsRemoteControlStreamer
    // To trigger updates.
    @ObservedObject var assistant: SettingsRemoteControlAssistant
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func remoteControlColor() -> Color {
        if model.isRemoteControlStreamerConfigured() && !model.isRemoteControlStreamerConnected() {
            return .red
        } else if model.isRemoteControlAssistantConfigured() && !model.isRemoteControlAssistantConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        if model.isShowingStatusRemoteControl() {
            StreamOverlayIconAndTextView(
                icon: "appletvremote.gen1",
                text: status.remoteControlStatus,
                textPlacement: textPlacement,
                color: remoteControlColor()
            )
        }
    }
}

private struct DjiDevicesStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusDjiDevices() {
            StreamOverlayIconAndTextView(
                icon: "appletvremote.gen1",
                text: status.djiDevicesStatus,
                textPlacement: textPlacement,
                color: .white
            )
        }
    }
}

private struct GameControllersStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusGameController() {
            StreamOverlayIconAndTextView(
                icon: "gamecontroller",
                text: status.gameControllersTotal,
                textPlacement: textPlacement
            )
        }
    }
}

private struct IngestsStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var ingests: Ingests
    // To trigger updates.
    @ObservedObject var rtmpServer: SettingsRtmpServer
    // To trigger updates.
    @ObservedObject var srtlaServer: SettingsSrtlaServer
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusIngests() {
            StreamOverlayIconAndTextView(
                icon: "server.rack",
                text: ingests.speedAndTotal,
                textPlacement: textPlacement
            )
        }
    }
}

private struct LocationStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var location: SettingsLocation
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusLocation() {
            StreamOverlayIconAndTextView(
                icon: "location",
                text: status.location,
                textPlacement: textPlacement
            )
        }
    }
}

private struct RecordingStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var recording: RecordingProvider
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusRecording() {
            StreamOverlayIconAndTextView(
                icon: "record.circle",
                text: recording.length,
                textPlacement: textPlacement
            )
        }
    }
}

private struct BrowserWidgetsStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusBrowserWidgets() {
            StreamOverlayIconAndTextView(
                icon: "globe",
                text: status.browserWidgetsStatus,
                textPlacement: textPlacement
            )
        }
    }
}

private struct CatPrinterStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func catPrinterColor() -> Color {
        if model.isAnyCatPrinterConfigured() && !model.areAllCatPrintersConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        if model.isShowingStatusCatPrinter() {
            StreamOverlayIconAndTextView(
                icon: "pawprint",
                text: status.catPrinterStatus,
                textPlacement: textPlacement,
                color: catPrinterColor()
            )
        }
    }
}

private struct CyclingPowerDeviceStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func cyclingPowerDeviceColor() -> Color {
        if model.isAnyCyclingPowerDeviceConfigured() && !model.areAllCyclingPowerDevicesConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        if model.isShowingStatusCyclingPowerDevice() {
            StreamOverlayIconAndTextView(
                icon: "bicycle",
                text: status.cyclingPowerDeviceStatus,
                textPlacement: textPlacement,
                color: cyclingPowerDeviceColor()
            )
        }
    }
}

private struct HeartRateDeviceStatusView: View {
    @EnvironmentObject var model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    private func heartRateDeviceColor() -> Color {
        if model.isAnyHeartRateDeviceConfigured() && !model.areAllHeartRateDevicesConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        if model.isShowingStatusHeartRateDevice() {
            StreamOverlayIconAndTextView(
                icon: "heart",
                text: status.heartRateDeviceStatus,
                textPlacement: textPlacement,
                color: heartRateDeviceColor()
            )
        }
    }
}

private struct FixedHorizonStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if model.isShowingStatusFixedHorizon() {
            StreamOverlayIconAndTextView(
                icon: "circle.and.line.horizontal",
                text: status.fixedHorizonStatus,
                textPlacement: textPlacement
            )
        }
    }
}

private struct BlackSharkCoolerDeviceStatusView: View {
    let model: Model
    // To trigger updates.
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if status.blackSharkCoolerDeviceState == .connected {
            StreamOverlayIconAndTextView(
                icon: "fan",
                text: """
                \(String(status.blackSharkCoolerPhoneTemp ?? 0)) °C / \
                \(String(status.blackSharkCoolerExhaustTemp ?? 0)) °C
                """,
                textPlacement: textPlacement
            )
        }
    }
}

private struct AutoSceneSwitcherStatusInnerView: View {
    @ObservedObject var autoSceneSwitcher: SettingsAutoSceneSwitcher
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "autostartstop",
            text: autoSceneSwitcher.name,
            textPlacement: textPlacement
        )
    }
}

private struct AutoSceneSwitcherStatusView: View {
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        if let autoSceneSwitcher = autoSceneSwitchers.switchers
            .first(where: { $0.id == autoSceneSwitchers.switcherId })
        {
            AutoSceneSwitcherStatusInnerView(autoSceneSwitcher: autoSceneSwitcher, textPlacement: textPlacement)
        }
    }
}

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopRight
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        HypeTrainStatusView(model: model,
                            hypeTrain: model.hypeTrain,
                            textPlacement: textPlacement)
        AdsRemainingTimerView(model: model,
                              status: model.statusTopRight,
                              textPlacement: textPlacement)
        IngestsStatusView(model: model,
                          show: model.database.show,
                          ingests: model.ingests,
                          rtmpServer: model.database.rtmpServer,
                          srtlaServer: model.database.srtlaServer,
                          textPlacement: textPlacement)
        MoblinkStatusView(model: model,
                          show: model.database.show,
                          moblink: model.moblink,
                          streamer: model.database.moblink.streamer,
                          relay: model.database.moblink.relay,
                          textPlacement: textPlacement)
        RemoteControlStatusView(model: model,
                                show: model.database.show,
                                status: model.statusTopRight,
                                streamer: model.database.remoteControl.streamer,
                                assistant: model.database.remoteControl.assistant,
                                textPlacement: textPlacement)
        DjiDevicesStatusView(model: model,
                             show: model.database.show,
                             status: model.statusTopRight,
                             textPlacement: textPlacement)
        GameControllersStatusView(model: model,
                                  show: model.database.show,
                                  status: model.statusTopRight,
                                  textPlacement: textPlacement)
        BitrateStatusView(model: model,
                          show: model.database.show,
                          bitrate: model.bitrate,
                          textPlacement: textPlacement)
        BondingStatusView(show: model.database.show,
                          bonding: model.bonding,
                          textPlacement: textPlacement)
        ReplayStatusView(show: model.database.show,
                         replay: model.stream.replay,
                         textPlacement: textPlacement)
        StreamUptimeStatusView(show: model.database.show,
                               streamUptime: model.streamUptime,
                               textPlacement: textPlacement)
        LocationStatusView(
            show: model.database.show,
            location: model.database.location,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        RecordingStatusView(
            show: model.database.show,
            recording: model.recording,
            textPlacement: textPlacement
        )
        BrowserWidgetsStatusView(
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        CatPrinterStatusView(
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        CyclingPowerDeviceStatusView(
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        HeartRateDeviceStatusView(
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        FixedHorizonStatusView(
            model: model,
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        BlackSharkCoolerDeviceStatusView(
            model: model,
            show: model.database.show,
            status: model.statusTopRight,
            textPlacement: textPlacement
        )
        AutoSceneSwitcherStatusView(
            autoSceneSwitchers: model.database.autoSceneSwitchers,
            textPlacement: textPlacement
        )
        CpuStatusView(model: model,
                      show: model.database.show,
                      systemMonitor: model.systemMonitor,
                      textPlacement: textPlacement)
        if show.audioLevel, textPlacement == .hide {
            CompactAudioBarView(level: model.audio.level)
        }
    }
}

private struct AudioView: View {
    let model: Model
    @ObservedObject var show: SettingsShow

    var body: some View {
        if show.audioLevel {
            AudioLevelView(model: model)
                .padding(20)
                .contentShape(Rectangle())
                .padding(-20)
        }
    }
}

struct RightOverlayTopView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            VStack(alignment: .trailing, spacing: 1) {
                if database.verboseStatuses {
                    AudioView(model: model, show: database.show)
                    StatusesView(show: database.show, status: model.statusTopRight, textPlacement: .beforeIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(show: database.show, status: model.statusTopRight, textPlacement: .hide)
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
    @ObservedObject var streamOverlay: StreamOverlay
    @ObservedObject var zoom: Zoom
    let width: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Spacer()
            if !(model.showDrawOnStream || model.showFace) {
                if streamOverlay.showingReplay {
                    StreamOverlayRightReplayView(replay: model.replay, orientation: model.orientation)
                } else {
                    if streamOverlay.showMediaPlayerControls {
                        StreamOverlayRightMediaPlayerControlsView(mediaPlayer: model.mediaPlayerPlayer)
                    } else {
                        if streamOverlay.showingPixellate {
                            StreamOverlayRightPixellateView(database: model.database)
                        }
                        if streamOverlay.showingWhirlpool {
                            StreamOverlayRightWhirlpoolView(database: model.database)
                        }
                        if streamOverlay.showingPinch {
                            StreamOverlayRightPinchView(database: model.database)
                        }
                        if streamOverlay.showingCamera {
                            StreamOverlayRightCameraSettingsControlView(model: model, show: model.show)
                        }
                        if show.zoomPresets && zoom.hasZoom {
                            StreamOverlayRightZoomPresetSelctorView(model: model,
                                                                    zoom: model.zoom,
                                                                    width: width)
                        }
                    }
                    StreamOverlayRightSceneSelectorView(database: model.database,
                                                        sceneSelector: model.sceneSelector,
                                                        width: width)
                }
            }
        }
    }
}
