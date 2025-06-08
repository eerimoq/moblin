import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preset: SettingsBitratePreset

    func submit(bitrate: String) {
        guard var bitrate = Float(bitrate) else {
            return
        }
        bitrate = max(bitrate, 0.05)
        bitrate = min(bitrate, 50)
        preset.bitrate = bitrateFromMbps(bitrate: bitrate)
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
