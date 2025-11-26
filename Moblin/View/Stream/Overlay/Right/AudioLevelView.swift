import SwiftUI

private let barWidthPerDb: Float = 1.0
private let barHeight: CGFloat = 5

private struct AudioBarView: View {
    @ObservedObject var audio: AudioProvider
    @ObservedObject var level: AudioLevel

    private func clippingBar() -> CGFloat? {
        guard level.level > clippingThresholdDb else {
            return nil
        }
        let db = -zeroThresholdDb
        return CGFloat(db * barWidthPerDb)
    }

    private func redBar() -> CGFloat? {
        guard level.level > redThresholdDb else {
            return nil
        }
        let db = level.level - redThresholdDb
        return CGFloat(db * barWidthPerDb)
    }

    private func yellowBar() -> CGFloat? {
        guard level.level > yellowThresholdDb else {
            return nil
        }
        let db = min(level.level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return CGFloat(db * barWidthPerDb)
    }

    private func greenBar() -> CGFloat? {
        guard level.level > zeroThresholdDb else {
            return nil
        }
        let db = min(level.level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return CGFloat(db * barWidthPerDb)
    }

    var body: some View {
        if level.level.isNaN {
            Text("Muted")
                .foregroundStyle(.white)
        } else if level.level == .infinity {
            Text("Unknown")
                .foregroundStyle(.white)
        } else {
            HStack(spacing: 0) {
                if let width = clippingBar() {
                    Rectangle()
                        .frame(width: width, height: barHeight)
                        .foregroundStyle(.red)
                } else {
                    if let width = redBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundStyle(.red)
                    }
                    if let width = yellowBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundStyle(.yellow)
                    }
                    if let width = greenBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding([.vertical], 2)
        }
    }
}

private struct ChannelsView: View {
    @ObservedObject var audio: AudioProvider

    var body: some View {
        if audio.numberOfChannels != 1 {
            Text(formatAudioLevelChannels(channels: audio.numberOfChannels))
                .foregroundStyle(.white)
        }
    }
}

private struct SampleRateView: View {
    @ObservedObject var audio: AudioProvider

    var body: some View {
        if audio.sampleRate != 48000 {
            Text(formatAudioLevelSampleRate(sampleRate: audio.sampleRate))
                .foregroundStyle(.white)
        }
    }
}

struct AudioLevelView: View {
    let model: Model

    var body: some View {
        HStack(spacing: 1) {
            HStack(spacing: 1) {
                AudioBarView(audio: model.audio, level: model.audio.level)
                ChannelsView(audio: model.audio)
                SampleRateView(audio: model.audio)
            }
            .padding([.leading, .trailing], 2)
            .background(backgroundColor)
            .cornerRadius(5)
            .font(smallFont)
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(.white)
                .background(backgroundColor)
                .cornerRadius(5)
        }
        .padding(0)
    }
}

struct CompactAudioBarView: View {
    @ObservedObject var level: AudioLevel

    var body: some View {
        if level.level.isNaN {
            CompactAudioLevelIconView(
                name: "microphone.slash",
                foregroundColor: .white,
                backgroundColor: backgroundColor
            )
        } else {
            let (foregroundColor, backgroundColor) = compactAudioLevelColors(level: level.level)
            CompactAudioLevelIconView(
                name: "waveform",
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
        }
    }
}
