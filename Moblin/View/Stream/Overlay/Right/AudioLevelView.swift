import SwiftUI

private let barsPerDb: Float = 1.0
private let clippingThresholdDb: Float = -1.0
private let redThresholdDb: Float = -8.5
private let yellowThresholdDb: Float = -20
private let zeroThresholdDb: Float = -60
private let barHeight: CGFloat = 5

private struct AudioBarView: View {
    @ObservedObject var audio: AudioProvider
    @ObservedObject var level: AudioLevel

    private func clippingBar() -> CGFloat? {
        guard level.level > clippingThresholdDb else {
            return nil
        }
        let db = -zeroThresholdDb
        return CGFloat(db * barsPerDb)
    }

    private func redBar() -> CGFloat? {
        guard level.level > redThresholdDb else {
            return nil
        }
        let db = level.level - redThresholdDb
        return CGFloat(db * barsPerDb)
    }

    private func yellowBar() -> CGFloat? {
        guard level.level > yellowThresholdDb else {
            return nil
        }
        let db = min(level.level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return CGFloat(db * barsPerDb)
    }

    private func greenBar() -> CGFloat? {
        guard level.level > zeroThresholdDb else {
            return nil
        }
        let db = min(level.level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return CGFloat(db * barsPerDb)
    }

    var body: some View {
        if level.level.isNaN {
            Text("Muted")
                .foregroundColor(.white)
        } else if level.level == .infinity {
            Text("Unknown")
                .foregroundColor(.white)
        } else {
            HStack(spacing: 0) {
                if let width = clippingBar() {
                    Rectangle()
                        .frame(width: width, height: barHeight)
                        .foregroundColor(.red)
                } else {
                    if let width = redBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundColor(.red)
                    }
                    if let width = yellowBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundColor(.yellow)
                    }
                    if let width = greenBar() {
                        Rectangle()
                            .frame(width: width, height: barHeight)
                            .foregroundColor(.green)
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
                .foregroundColor(.white)
        }
    }
}

private struct SampleRateView: View {
    @ObservedObject var audio: AudioProvider

    var body: some View {
        if audio.sampleRate != 48000 {
            Text(formatAudioLevelSampleRate(sampleRate: audio.sampleRate))
                .foregroundColor(.white)
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
                .padding([.bottom], 2)
                .foregroundColor(.white)
                .background(backgroundColor)
                .cornerRadius(5)
        }
        .padding(0)
    }
}

struct CompactAudioBarView: View {
    @ObservedObject var level: AudioLevel

    private func colors() -> (Color, Color) {
        if level.level == .infinity {
            return (.brown, backgroundColor)
        } else if level.level > clippingThresholdDb {
            return (.white, .red)
        } else if level.level > redThresholdDb {
            return (.red, backgroundColor)
        } else if level.level > yellowThresholdDb {
            return (.yellow, backgroundColor)
        } else if level.level > zeroThresholdDb {
            return (.green, backgroundColor)
        } else {
            return (.white, backgroundColor)
        }
    }

    var body: some View {
        if level.level.isNaN {
            Image(systemName: "microphone.slash")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .padding([.bottom], 2)
                .foregroundColor(.white)
                .background(backgroundColor)
                .cornerRadius(5)
        } else {
            let (foregroundColor, backgroundColor) = colors()
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .padding([.bottom], 2)
                .foregroundColor(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(5)
        }
    }
}
