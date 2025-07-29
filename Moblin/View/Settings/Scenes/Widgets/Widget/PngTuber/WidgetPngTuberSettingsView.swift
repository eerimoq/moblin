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

struct WidgetPngTuberSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var pngTuber: SettingsWidgetPngTuber
    @State var showPicker = false

    private func onUrl(url: URL) {
        pngTuber.modelName = url.lastPathComponent
        model.pngTuberStorage.add(id: pngTuber.id, url: url)
        model.resetSelectedScene(changeScene: false)
    }

    private func onCameraChange(cameraId: String) {
        pngTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    private func setEffectSettings() {
        model.getPngTuberEffect(id: widget.id)?.setSettings(mirror: pngTuber.mirror)
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    items: model.listCameraPositions(excludeBuiltin: false).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(pngTuberWidget: pngTuber)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    Text(model.getCameraPositionName(pngTuberWidget: pngTuber))
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
                    Text(pngTuber.modelName.isEmpty ? String(localized: "Select model") : pngTuber.modelName)
                }
            }
            .sheet(isPresented: $showPicker) {
                PickerView()
            }
        } header: {
            Text("Model")
        } footer: {
            Text("A .save-file from PNGTuberPlus.")
        }
        Section {
            Toggle(isOn: $pngTuber.mirror) {
                Text("Mirror")
            }
            .onChange(of: pngTuber.mirror) { _ in
                setEffectSettings()
            }
        }
    }
}
