import PhotosUI
import SwiftUI

struct WidgetTextSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitFormatString(value: String) {
        widget.text.formatString = value
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            TextEditNavigationView(
                title: "Format",
                value: widget.text.formatString,
                onSubmit: submitFormatString,
                footers: [
                    String(localized: "{time} - Show time as HH:MM:SS"),
                    String(localized: "{speed} - Show speed (if Settings → Location is enabled)"),
                    String(localized: "{altitude} - Show altitude (if Settings → Location is enabled)"),
                    String(localized: "{distance} - Show distance (if Settings → Location is enabled)"),
                    String(localized: "{bitrateAndTotal} - Show bitrate and total number of bytes sent"),
                    String(localized: "{debugOverlay} - Show debug overlay (if enabled)"),
                ]
            )
        }
    }
}
