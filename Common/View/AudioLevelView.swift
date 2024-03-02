import SwiftUI

private let barsPerDb: Float = 0.3
private let clippingThresholdDb: Float = -1.0
private let redThresholdDb: Float = -8.5
private let yellowThresholdDb: Float = -20
private let zeroThresholdDb: Float = -60

// Approx 60 * 0.3 = 20
private let maxBars = "||||||||||||||||||||"

struct AudioLevelView: View {
    var showBar: Bool
    var level: Float
    var channels: Int?

    private func bars(count: Float) -> Substring {
        let barCount = Int(count.rounded(.toNearestOrAwayFromZero))
        return maxBars.prefix(barCount)
    }

    private func isClipping() -> Bool {
        return level > clippingThresholdDb
    }

    private func clippingText() -> Substring {
        let db = -zeroThresholdDb
        return bars(count: db * barsPerDb)
    }

    private func redText() -> Substring {
        guard level > redThresholdDb else {
            return ""
        }
        let db = level - redThresholdDb
        return bars(count: db * barsPerDb)
    }

    private func yellowText() -> Substring {
        guard level > yellowThresholdDb else {
            return ""
        }
        let db = min(level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return bars(count: db * barsPerDb)
    }

    private func greenText() -> Substring {
        guard level > zeroThresholdDb else {
            return ""
        }
        let db = min(level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return bars(count: db * barsPerDb)
    }

    var body: some View {
        HStack(spacing: 1) {
            HStack(spacing: 1) {
                if level.isNaN {
                    if channels == nil {
                        Text("Muted")
                            .foregroundColor(.white)
                    } else {
                        Text("Muted,")
                            .foregroundColor(.white)
                    }
                } else if level == .infinity {
                    if channels == nil {
                        Text("Unknown")
                            .foregroundColor(.white)
                    } else {
                        Text("Unknown,")
                            .foregroundColor(.white)
                    }
                } else {
                    if showBar {
                        HStack(spacing: 0) {
                            if isClipping() {
                                Text(clippingText())
                                    .foregroundColor(.red)
                            } else {
                                Text(redText())
                                    .foregroundColor(.red)
                                Text(yellowText())
                                    .foregroundColor(.yellow)
                                Text(greenText())
                                    .foregroundColor(.green)
                            }
                        }
                        .padding([.bottom], 2)
                        .bold()
                    } else {
                        Text(formatAudioLevelDb(level: level))
                            .foregroundColor(.white)
                    }
                }
                if let channels {
                    Text(formatAudioLevelChannels(channels: channels))
                        .foregroundColor(.white)
                }
            }
            .padding([.leading, .trailing], 2)
            .background(Color(white: 0, opacity: 0.6))
            .cornerRadius(5)
            .font(smallFont)
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .padding([.bottom], showBar ? 2 : 0)
                .foregroundColor(.white)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(5)
        }
        .padding(0)
    }
}
