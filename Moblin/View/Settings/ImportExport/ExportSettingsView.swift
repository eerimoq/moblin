import SwiftUI

struct ExportSettingsView: View {
    let model: Model
    @State private var url: URL?

    var body: some View {
        HCenter {
            if let url {
                ShareLink(item: url) {
                    Text("Export")
                }
            } else {
                ProgressView()
            }
        }
        .disabled(url == nil)
        .onAppear {
            url = model.settings.exportToFile()
        }
    }
}
