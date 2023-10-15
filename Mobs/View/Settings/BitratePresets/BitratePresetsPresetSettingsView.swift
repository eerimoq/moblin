import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @ObservedObject var model: Model
    private var preset: SettingsBitratePreset

    init(model: Model, preset: SettingsBitratePreset) {
        self.model = model
        self.preset = preset
    }

    func submit(bitrate: String) {
        guard let bitrate = Float(bitrate) else {
            return
        }
        guard bitrate > 0 else {
            model.makeErrorToast(title: "Bitrate must be greater than zero")
            return
        }
        preset.bitrate = max(bitrateFromMbps(bitrate: bitrate), 100_000)
        model.store()
    }

    var body: some View {
        TextEditView(
            title: "Bitrate",
            value: String(bitrateToMbps(bitrate: preset.bitrate)),
            onSubmit: submit
        )
    }
}
