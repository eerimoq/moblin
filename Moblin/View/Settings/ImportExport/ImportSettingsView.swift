import SwiftUI

struct ImportSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button("Import from clipboard") {
                if let message = model.settings.importFromClipboard() {
                    model.makeErrorToast(
                        title: "Import settings failed",
                        subTitle: message
                    )
                } else {
                    model.makeToast(title: "Settings imported")
                    model.updateIconImageFromDatabase()
                }
            }
            Spacer()
        }
    }
}
