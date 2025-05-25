import SwiftUI

private struct PickerView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

struct WidgetVTuberSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var showPicker = false

    private func onUrl(url: URL) {
        model.vTuberStorage.add(id: widget.vTuber.id, url: url)
    }

    var body: some View {
        Section {
            Button {
                showPicker = true
                model.onDocumentPickerUrl = onUrl
            } label: {
                HCenter {
                    Text("Select model")
                }
            }
            .sheet(isPresented: $showPicker) {
                PickerView()
            }
        } header: {
            Text("Model")
        }
    }
}
