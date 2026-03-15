import SwiftUI

struct ExportSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var exportUrl: URL?
    @State private var isPresentingExporter = false

    var body: some View {
        TextButtonView("Export to file") {
            if let url = model.settings.exportToFile() {
                exportUrl = url
                isPresentingExporter = true
            }
        }
        .sheet(isPresented: $isPresentingExporter) {
            if let exportUrl {
                ShareView(activityItems: [exportUrl])
            }
        }
    }
}

private struct ShareView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
