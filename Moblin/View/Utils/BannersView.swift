import SwiftUI

private let bannerBackgroundColor = RgbColor(red: 0x64, green: 0x41, blue: 0xA5).color()

private struct ProgressBarView: View {
    @ObservedObject var progress: ProgressBar

    var body: some View {
        ProgressView(value: progress.goal - progress.progress, total: progress.goal)
            .accentColor(.white)
            .scaleEffect(x: 1, y: 4, anchor: .center)
            .padding([.top, .leading, .trailing], 10)
            .padding(.bottom, 20)
    }
}

private struct HypeTrainView: View {
    let model: Model
    @ObservedObject var hypeTrain: HypeTrain

    var body: some View {
        VStack {
            if let level = hypeTrain.level {
                HStack(spacing: 0) {
                    let train = HStack(spacing: 0) {
                        Image(systemName: "train.side.rear.car")
                        Image(systemName: "train.side.middle.car")
                        Image(systemName: "train.side.middle.car")
                        Image(systemName: "train.side.middle.car")
                        Image(systemName: "train.side.front.car")
                    }
                    if #available(iOS 18.0, *) {
                        train
                            .symbolEffect(
                                .wiggle.forward.byLayer,
                                options: .repeat(.periodic(delay: 2.0))
                            )
                    } else {
                        train
                    }
                    Spacer()
                    Text("LEVEL \(level)")
                    Button {
                        model.removeHypeTrain()
                    } label: {
                        Text("Close")
                    }
                    .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                .padding(10)
            }
            if let progress = hypeTrain.progress {
                ProgressBarView(progress: progress)
            }
        }
        .background(bannerBackgroundColor)
    }
}

private struct RaidView: View {
    let model: Model
    @ObservedObject var raid: Raid

    private func close() {
        switch raid.state {
        case .idle:
            break
        case .ongoing:
            raid.message = String(localized: "Cancelling raid")
            model.cancelRaidTwitchChannel {
                switch $0 {
                case .success:
                    break
                default:
                    raid.message = String(localized: "Failed to cancel the raid")
                    raid.state = .completed
                }
            }
            raid.state = .cancelling
        case .cancelling:
            break
        case .completed:
            raid.state = .idle
        }
    }

    var body: some View {
        if raid.state != .idle {
            VStack {
                HStack {
                    ChannelImageView(image: raid.channelImage)
                    VStack(alignment: .leading) {
                        Text(raid.message)
                        if let url = URL(string: "https://twitch.tv/\(raid.channelLogin)") {
                            Link(destination: url) {
                                Text(String("twitch.tv/\(raid.channelLogin)"))
                                    .font(.footnote)
                                    .underline()
                            }
                        }
                    }
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Text(raid.state == .ongoing ? "Cancel" : "Close")
                    }
                    .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                .padding(10)
                ProgressBarView(progress: raid.progress)
            }
            .background(bannerBackgroundColor)
        }
    }
}

private struct OptionBarView: View {
    let title: String
    let detail: String
    let fraction: Double
    let color: Color
    let bold: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .lineLimit(1)
                Spacer()
                Text(detail)
            }
            .font(.footnote)
            .bold(bold)
            ProgressView(value: fraction)
                .tint(color)
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
    }
}

private struct BannerView<Content: View>: View {
    let image: String
    let title: String
    let message: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: image)
                Text(title)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Text("Close")
                }
                .buttonStyle(.bordered)
            }
            content
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(bannerBackgroundColor)
    }
}

private struct TwitchPollView: View {
    let model: Model
    @ObservedObject var poll: TwitchPoll

    private func fraction(votes: Int) -> Double {
        guard poll.totalVotes > 0 else {
            return 0
        }
        return Double(votes) / Double(poll.totalVotes)
    }

    var body: some View {
        if poll.state != .idle {
            BannerView(image: "chart.bar", title: poll.title, message: poll.message) {
                model.removeTwitchPoll()
            } content: {
                ForEach(poll.choices) { choice in
                    let fraction = fraction(votes: choice.votes)
                    let percentage = Int(100 * fraction)
                    OptionBarView(title: choice.title,
                                  detail: String(localized: "\(percentage)% (\(choice.votes) votes)"),
                                  fraction: fraction,
                                  color: .white,
                                  bold: false)
                }
            }
        }
    }
}

private struct TwitchPredictionView: View {
    let model: Model
    @ObservedObject var prediction: TwitchPrediction

    private func fraction(channelPoints: Int) -> Double {
        guard prediction.totalChannelPoints > 0 else {
            return 0
        }
        return Double(channelPoints) / Double(prediction.totalChannelPoints)
    }

    private func color(outcome: TwitchPredictionOutcome) -> Color {
        if outcome.color == "pink" {
            RgbColor(red: 0xF5, green: 0x00, blue: 0x9B).color()
        } else {
            RgbColor(red: 0x38, green: 0x7A, blue: 0xFF).color()
        }
    }

    var body: some View {
        if prediction.state != .idle {
            BannerView(image: "sparkles", title: prediction.title, message: prediction.message) {
                model.removeTwitchPrediction()
            } content: {
                ForEach(prediction.outcomes) { outcome in
                    let fraction = fraction(channelPoints: outcome.channelPoints)
                    let percentage = Int(100 * fraction)
                    OptionBarView(
                        title: outcome.title,
                        detail: String(
                            localized: "\(percentage)% (\(outcome.channelPoints) points, \(outcome.users) users)"
                        ),
                        fraction: fraction,
                        color: color(outcome: outcome),
                        bold: outcome.winner
                    )
                }
            }
        }
    }
}

private struct MinimizedView: View {
    @ObservedObject var hypeTrain: HypeTrain
    @ObservedObject var raid: Raid
    @ObservedObject var poll: TwitchPoll
    @ObservedObject var prediction: TwitchPrediction

    private func icons() -> [String] {
        var icons: [String] = []
        if hypeTrain.level != nil || hypeTrain.progress != nil {
            icons.append("train.side.front.car")
        }
        if raid.state != .idle {
            icons.append("figure.run")
        }
        if poll.state != .idle {
            icons.append("chart.bar")
        }
        if prediction.state != .idle {
            icons.append("sparkles")
        }
        return icons
    }

    var body: some View {
        let icons = icons()
        if !icons.isEmpty {
            HStack {
                ForEach(icons, id: \.self) { icon in
                    Image(systemName: icon)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(bannerBackgroundColor)
            .clipShape(Capsule())
            .padding(.top, 5)
        }
    }
}

struct BannersView: View {
    let model: Model
    @ObservedObject var banners: Banners
    @State private var contentHeight = 0.0

    var body: some View {
        GeometryReader { metrics in
            VStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .background(.clear)
                    .frame(height: 1)
                Group {
                    if banners.minimized {
                        MinimizedView(hypeTrain: model.hypeTrain,
                                      raid: model.raid,
                                      poll: model.twitchPoll,
                                      prediction: model.twitchPrediction)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                HypeTrainView(model: model, hypeTrain: model.hypeTrain)
                                RaidView(model: model, raid: model.raid)
                                TwitchPollView(model: model, poll: model.twitchPoll)
                                TwitchPredictionView(model: model, prediction: model.twitchPrediction)
                            }
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                contentHeight = height
                            }
                        }
                        .frame(height: min(contentHeight, metrics.size.height - 1))
                    }
                }
                .onTapGesture {
                    banners.minimized.toggle()
                }
                Spacer()
            }
        }
    }
}
