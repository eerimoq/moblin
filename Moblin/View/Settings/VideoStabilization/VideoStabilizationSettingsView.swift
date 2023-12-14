import SwiftUI

struct VideoStabilizationSettingsView: View {
    @EnvironmentObject var model: Model

    private func onChange(mode: String) {
        model.database
            .videoStabilizationMode = SettingsVideoStabilizationMode.fromString(value: mode)
        model.store()
        model.reattachCamera()
    }

    var body: some View {
        NavigationLink(destination: InlinePickerView(
            title: String(localized: "Video stabilization"),
            onChange: onChange,
            footers: [String(localized: "Video stabilization sometimes gives audio-video sync issues.")],
            items: videoStabilizationModes,
            selected: model.database.videoStabilizationMode.toString()
        )) {
            TextItemView(
                name: String(localized: "Video stabilization"),
                value: model.database.videoStabilizationMode.toString()
            )
        }
    }
}
