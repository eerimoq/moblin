import SwiftUI

private let barWidthPerDb: Float = 1.0
private let barHeight: CGFloat = 5
private let bigBarScale: CGFloat = 2.5

private struct AudioBarView: View {
    @ObservedObject var level: AudioLevel
    var big: Bool = false

    private func clippingBar(scale: CGFloat) -> CGFloat? {
        guard level.level > clippingThresholdDb else {
            return nil
        }
        let db = -zeroThresholdDb
        return CGFloat(db * barWidthPerDb) * scale
    }

    private func redBar(scale: CGFloat) -> CGFloat? {
        guard level.level > redThresholdDb else {
            return nil
        }
        let db = level.level - redThresholdDb
        return CGFloat(db * barWidthPerDb) * scale
    }

    private func yellowBar(scale: CGFloat) -> CGFloat? {
        guard level.level > yellowThresholdDb else {
            return nil
        }
        let db = min(level.level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return CGFloat(db * barWidthPerDb) * scale
    }

    private func greenBar(scale: CGFloat) -> CGFloat? {
        guard level.level > zeroThresholdDb else {
            return nil
        }
        let db = min(level.level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return CGFloat(db * barWidthPerDb) * scale
    }

    var body: some View {
        let scale = big ? bigBarScale : 1.0
        if level.isMuted() {
            Text("Muted")
                .foregroundStyle(.white)
        } else if level.isUnknown() {
            Text("Unknown")
                .foregroundStyle(.white)
        } else {
            HStack(spacing: 0) {
                if let width = clippingBar(scale: scale) {
                    Rectangle()
                        .frame(width: width, height: barHeight * scale)
                        .foregroundStyle(.red)
                } else {
                    if let width = redBar(scale: scale) {
                        Rectangle()
                            .frame(width: width, height: barHeight * scale)
                            .foregroundStyle(.red)
                    }
                    if let width = yellowBar(scale: scale) {
                        Rectangle()
                            .frame(width: width, height: barHeight * scale)
                            .foregroundStyle(.yellow)
                    }
                    if let width = greenBar(scale: scale) {
                        Rectangle()
                            .frame(width: width, height: barHeight * scale)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 2)
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
    var big: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            HStack(spacing: 1) {
                AudioBarView(level: model.audio.level, big: big)
                ChannelsView(audio: model.audio)
                SampleRateView(audio: model.audio)
            }
            .padding(.horizontal, 2)
            .background(backgroundColor)
            .cornerRadius(5)
            .font(smallFont)
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding(.horizontal, 2)
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
