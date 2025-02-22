import Charts
import SwiftUI

private struct CollapsedBondingView: View {
    @EnvironmentObject var model: Model
    var show: Bool
    var color: Color

    var body: some View {
        if show {
            HStack(spacing: 1) {
                Image(systemName: "phone.connection")
                    .frame(width: 17, height: 17)
                    .font(smallFont)
                    .padding([.leading, .trailing], 2)
                    .foregroundColor(color)
                if #available(iOS 17.0, *) {
                    if !model.bondingPieChartPercentages.isEmpty {
                        Chart(model.bondingPieChartPercentages.reversed()) { item in
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
}

private struct CollapsedHypeTrainView: View {
    @EnvironmentObject var model: Model
    var show: Bool
    var color: Color

    var body: some View {
        if show {
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
                Text(model.hypeTrainStatus)
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
}

private struct CollapsedAdsRemainingTimerView: View {
    @EnvironmentObject var model: Model
    var show: Bool
    var color: Color

    var body: some View {
        if show {
            HStack(spacing: 1) {
                Image(systemName: "cup.and.saucer")
                    .frame(width: 17, height: 17)
                    .padding([.leading, .trailing], 2)
                    .foregroundColor(color)
                Text(model.adsRemainingTimerStatus)
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
}

private struct CollapsedBitrateView: View {
    @EnvironmentObject var model: Model
    var show: Bool
    var color: Color

    var body: some View {
        if show {
            HStack(spacing: 1) {
                Image(systemName: "speedometer")
                    .frame(width: 17, height: 17)
                    .padding([.leading], 2)
                    .foregroundColor(color)
                if !model.speedMbpsOneDecimal.isEmpty {
                    Text(model.speedMbpsOneDecimal)
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
}

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

    private func moblinkColor() -> Color {
        if model.isMoblinkRelayConfigured() && !model.areMoblinkRelaysOk() {
            return .red
        }
        if !model.moblinkStreamerOk {
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

    var body: some View {
        if textPlacement == .hide {
            CollapsedHypeTrainView(show: model.isShowingStatusHypeTrain(), color: .white)
        } else {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusHypeTrain(),
                icon: "train.side.front.car",
                text: model.hypeTrainStatus,
                textPlacement: textPlacement,
                color: .white
            )
        }
        if textPlacement == .hide {
            CollapsedAdsRemainingTimerView(show: model.isShowingStatusAdsRemainingTimer(), color: .white)
        } else {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusAdsRemainingTimer(),
                icon: "cup.and.saucer",
                text: "\(model.adsRemainingTimerStatus) seconds",
                textPlacement: textPlacement,
                color: .white
            )
        }
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusServers(),
            icon: "server.rack",
            text: model.serversSpeedAndTotal,
            textPlacement: textPlacement,
            color: .white
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusMoblink(),
            icon: "app.connected.to.app.below.fill",
            text: model.moblinkStatus,
            textPlacement: textPlacement,
            color: moblinkColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusRemoteControl(),
            icon: "appletvremote.gen1",
            text: model.remoteControlStatus,
            textPlacement: textPlacement,
            color: remoteControlColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusDjiDevices(),
            icon: "appletvremote.gen1",
            text: model.djiDevicesStatus,
            textPlacement: textPlacement,
            color: djiDevicesColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusGameController(),
            icon: "gamecontroller",
            text: model.gameControllersTotal,
            textPlacement: textPlacement,
            color: .white
        )
        if textPlacement == .hide {
            CollapsedBitrateView(show: model.isShowingStatusBitrate(), color: model.bitrateStatusColor)
        } else {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBitrate(),
                icon: "speedometer",
                text: model.speedAndTotal,
                textPlacement: textPlacement,
                color: model.bitrateStatusColor
            )
        }
        if textPlacement == .hide {
            CollapsedBondingView(show: model.isShowingStatusBonding(), color: netStreamColor())
        } else {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBonding(),
                icon: "phone.connection",
                text: model.bondingStatistics,
                textPlacement: textPlacement,
                color: netStreamColor()
            )
        }
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusBondingRtts(),
            icon: "phone.connection",
            text: model.bondingRtts,
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
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusCatPrinter(),
            icon: "pawprint",
            text: model.catPrinterStatus,
            textPlacement: textPlacement,
            color: catPrinterColor()
        )
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
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            VStack(alignment: .trailing, spacing: 1) {
                AudioView(audio: model.audio)
                if model.verboseStatuses {
                    StatusesView(textPlacement: .beforeIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(textPlacement: .hide)
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
    let width: CGFloat

    private var database: Database {
        model.settings.database
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Spacer()
            if !(model.showDrawOnStream || model.showFace) {
                if model.showMediaPlayerControls {
                    StreamOverlayRightMediaPlayerControlsView()
                } else {
                    if model.showingPixellate {
                        StreamOverlayRightPixellateView(strength: model.database.pixellateStrength!)
                    }
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
