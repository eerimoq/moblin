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
        vTuber.modelName = url.lastPathComponent
        model.vTuberStorage.add(id: vTuber.id, url: url)
        model.resetSelectedScene(changeScene: false)
    }

    private func onCameraChange(cameraId: String) {
        vTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    private func setEffectSettings() {
        model.getVTuberEffect(id: widget.id)?
            .setSettings(
                cameraFieldOfView: vTuber.cameraFieldOfView,
                cameraPositionY: vTuber.cameraPositionY,
                mirror: vTuber.mirror
            )
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
                    Text(vTuber.modelName.isEmpty ? String(localized: "Select model") : vTuber.modelName)
                }
            }
            .sheet(isPresented: $showPicker) {
                PickerView()
            }
        } header: {
            Text("Model")
        } footer: {
            Text("Most VRM 0.0 files are supported.")
        }
        Section {
            HStack {
                Text("Vertical position")
                Slider(
                    value: $vTuber.cameraPositionY,
                    in: 1 ... 2,
                    step: 0.01
                )
                .onChange(of: vTuber.cameraPositionY) { _ in
                    setEffectSettings()
                }
            }
            HStack {
                Text("Field of view")
                Slider(
                    value: $vTuber.cameraFieldOfView,
                    in: 10 ... 30,
                    step: 1.0
                )
                .onChange(of: vTuber.cameraFieldOfView) { _ in
                    setEffectSettings()
                }
            }
            Section {
                Toggle(isOn: $vTuber.mirror) {
                    Text("Mirror")
                }
                .onChange(of: vTuber.mirror) { _ in
                    setEffectSettings()
                }
            }
        } header: {
            Text("Camera")
        }
    }
}
