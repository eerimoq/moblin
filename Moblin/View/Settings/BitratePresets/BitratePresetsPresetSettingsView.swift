import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var preset: SettingsBitratePreset

    func submit(bitrate: String) {
        guard let bitrate = Float(bitrate) else {
            return
        }
        guard bitrate > 0 else {
            model.makeErrorToast(title: String(localized: "Bitrate must be greater than zero"))
            return
        }
        preset.bitrate = max(bitrateFromMbps(bitrate: bitrate), 100_000)
        model.store()
    }

    var body: some View {
        TextEditView(
            title: String(localized: "Bitrate"),
            value: String(bitrateToMbps(bitrate: preset.bitrate)),
            onSubmit: submit
        )
    }
}
