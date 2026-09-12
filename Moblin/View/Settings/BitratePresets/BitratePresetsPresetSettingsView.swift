import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @ObservedObject var preset: SettingsBitratePreset

    func submit(bitrate: String) {
        guard let bitrate = Float(bitrate) else {
            return
        }
        preset.bitrate = bitrateFromMbps(bitrate: bitrate.clamped(to: 0.05 ... 50))
    }

    var body: some View {
        NavigationLink {
            TextEditView(
                title: String(localized: "Bitrate"),
                value: String(bitrateToMbps(bitrate: preset.bitrate)),
                keyboardType: .numbersAndPunctuation
            ) {
                submit(bitrate: $0)
            }
        } label: {
            HStack {
                DraggableItemPrefixView()
                TextItemView(
                    name: formatBytesPerSecond(speed: Int64(preset.bitrate)),
                    value: String(bitrateToMbps(bitrate: preset.bitrate))
                )
            }
        }
    }
}
