import AVFoundation
import SwiftUI

struct BitratePresetsPresetSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    private var preset: SettingsBitratePreset

    init(model: Model, preset: SettingsBitratePreset, toolbar: Toolbar) {
        self.model = model
        self.preset = preset
        self.toolbar = toolbar
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
            toolbar: toolbar,
            title: "Bitrate",
            value: String(bitrateToMbps(bitrate: preset.bitrate)),
            onSubmit: submit
        )
    }
}
