import PhotosUI
import SwiftUI

struct WidgetQrCodeSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitMessage(value: String) {
        widget.qrCode!.message = value
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            TextEditNavigationView(
                title: "Message",
                value: widget.qrCode!.message,
                onSubmit: submitMessage
            )
        }
    }
}
