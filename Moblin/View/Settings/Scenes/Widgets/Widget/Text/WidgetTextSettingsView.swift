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
                onSubmit: submitFormatString
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("{time} - Show time as HH:MM:SS")
                Text("{bitrateAndTotal} - Show bitrate and total number of bytes sent")
                Text("{debugOverlay} - Show debug overlay (if enabled)")
            }
        }
    }
}
