import SwiftUI

let clippingThresholdDb: Float = -1.0
let redThresholdDb: Float = -8.5
let yellowThresholdDb: Float = -20
let zeroThresholdDb: Float = -60
let defaultAudioLevel: Float = -160.0

struct CompactAudioLevelIconView: View {
    let name: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Image(systemName: name)
            .frame(width: 17, height: 17)
            .font(smallFont)
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(5)
            .padding(20)
            .contentShape(Rectangle())
            .padding(-20)
    }
}

func compactAudioLevelColors(level: Float) -> (Color, Color) {
    if level == .infinity {
        (.brown, backgroundColor)
    } else if level > clippingThresholdDb {
        (.white, .red)
    } else if level > redThresholdDb {
        (.red, backgroundColor)
    } else if level > yellowThresholdDb {
        (.yellow, backgroundColor)
    } else if level > zeroThresholdDb {
        (.green, backgroundColor)
    } else {
        (.white, backgroundColor)
    }
}
