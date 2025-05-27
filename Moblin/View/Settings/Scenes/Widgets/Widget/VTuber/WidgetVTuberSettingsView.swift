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
    @ObservedObject var vTuber: SettingsWidgetVTuber
    @State var showPicker = false

    private func onUrl(url: URL) {
        model.vTuberStorage.add(id: widget.vTuber.id, url: url)
    }

    private func onCameraChange(cameraId: String) {
        widget.vTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    footers: [
                        String(localized: """
                        Limitation: At most one built-in or USB camera is \
                        supported at a time in a scene.
                        """),
                    ],
                    items: model.listCameraPositions(excludeBuiltin: false).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(vTuberWidget: vTuber)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    Text(model.getCameraPositionName(vTuberWidget: vTuber))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
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
