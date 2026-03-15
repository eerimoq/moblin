import SwiftUI

struct ExportSettingsView: View {
    @ObservedObject var model: Model
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
        .onAppear {
            model.settings.exportToFile { url in
                DispatchQueue.main.async {
                    self.url = url
                }
            }
        }
    }
}
