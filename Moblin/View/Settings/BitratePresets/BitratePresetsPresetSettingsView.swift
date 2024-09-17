import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var preset: SettingsBitratePreset

    func submit(bitrate: String) {
        guard var bitrate = Float(bitrate) else {
            return
        }
        bitrate = max(bitrate, 0.1)
        bitrate = min(bitrate, 50)
        preset.bitrate = bitrateFromMbps(bitrate: bitrate)
        model.store()
    }

    var body: some View {
        TextEditView(
            title: String(localized: "Bitrate"),
            value: String(bitrateToMbps(bitrate: preset.bitrate)),
            onSubmit: submit,
            keyboardType: .numbersAndPunctuation
        )
    }
}
