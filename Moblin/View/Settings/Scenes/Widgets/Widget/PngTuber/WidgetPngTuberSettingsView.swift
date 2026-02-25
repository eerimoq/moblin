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

struct WidgetPngTuberPickerView: View {
    let model: Model
    @ObservedObject var pngTuber: SettingsWidgetPngTuber
    var onSelected: (() -> Void)?
    @State private var showPicker = false

    private func onUrl(url: URL) {
        pngTuber.modelName = url.lastPathComponent
        model.pngTuberStorage.add(id: pngTuber.id, url: url)
        onSelected?()
    }

    var body: some View {
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
    }
}

struct WidgetSensitivityView: View {
    @Binding var sensitivity: SettingsSensitivity

    var body: some View {
        Section {
            HStack {
                Text("Mouth")
                Slider(value: $sensitivity.mouth, in: 0.05 ... 3)
            }
            HStack {
                Text("Eyes")
                Slider(value: $sensitivity.eyes, in: 0.05 ... 5)
            }
        } header: {
            Text("Sensitivity")
        }
    }
}

struct WidgetPngTuberSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var pngTuber: SettingsWidgetPngTuber

    private func onCameraChange(cameraId: String) {
        pngTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    private func setEffectSettings() {
        model.getPngTuberEffect(id: widget.id)?.setSettings(mirror: pngTuber.mirror,
                                                            sensitivity: pngTuber.sensitivity)
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: "Video source",
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
                    GrayTextView(text: model.getCameraPositionName(pngTuberWidget: pngTuber))
                }
            }
        }
        WidgetPngTuberPickerView(model: model, pngTuber: pngTuber) {
            model.resetSelectedScene(changeScene: false)
        }
        WidgetSensitivityView(sensitivity: $pngTuber.sensitivity)
            .onChange(of: pngTuber.sensitivity) { _ in
                setEffectSettings()
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
