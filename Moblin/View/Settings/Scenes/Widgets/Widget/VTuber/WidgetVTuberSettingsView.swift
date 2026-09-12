import SwiftUI
import ZipArchive

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

private func unzipLive2DModel(from url: URL, to directory: URL) throws {
    try ZipArchiveReader.withFile(url.path) { reader in
        for entry in try reader.readDirectory() where !entry.isDirectory {
            let components = entry.filename.components.map(\.string)
            if components.contains("__MACOSX") || components.contains("..") {
                continue
            }
            let file = directory.appending(path: components.joined(separator: "/"))
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data(reader.readFile(entry)).write(to: file)
        }
    }
}

struct WidgetVTuberPickerView: View {
    let model: Model
    @ObservedObject var vTuber: SettingsWidgetVTuber
    var onSelected: (() -> Void)?
    @State var showPicker = false

    private func onUrl(url: URL) {
        if url.pathExtension.lowercased() == "zip" {
            onLive2DUrl(url: url)
        } else {
            vTuber.type = .vrm
            vTuber.modelName = url.lastPathComponent
            model.vTuberStorage.add(id: vTuber.id, url: url)
            onSelected?()
        }
    }

    private func onLive2DUrl(url: URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        DispatchQueue.global().async {
            do {
                try unzipLive2DModel(from: url, to: directory)
            } catch {
                DispatchQueue.main.async {
                    model.makeErrorToast(title: String(localized: "Failed to unzip model"),
                                         subTitle: error.localizedDescription)
                }
                return
            }
            DispatchQueue.main.async {
                vTuber.type = .live2D
                vTuber.modelName = url.lastPathComponent
                model.vTuberStorage.add(id: vTuber.id, url: directory)
                onSelected?()
            }
        }
    }

    var body: some View {
        Section {
            TextButtonView(title: vTuber.modelName.isEmpty ? String(localized: "Select model") : vTuber
                .modelName)
            {
                showPicker = true
                model.onDocumentPickerUrl = onUrl
            }
            .sheet(isPresented: $showPicker) {
                PickerView()
            }
        } header: {
            Text("Model")
        } footer: {
            Text("Most VRM 0.0 files and zipped Live2D Cubism models are supported.")
        }
    }
}

struct WidgetVTuberSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var vTuber: SettingsWidgetVTuber

    private func onCameraChange(cameraId: String) {
        vTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    private func setEffectSettings() {
        model.getVTuberEffect(id: widget.id)?
            .setSettings(
                cameraFieldOfView: vTuber.cameraFieldOfView,
                cameraPositionY: vTuber.cameraPositionY,
                mirror: vTuber.mirror,
                sensitivity: vTuber.sensitivity,
                armsAngle: vTuber.armsAngle
            )
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: "Video source",
                    onChange: onCameraChange,
                    items: model.listCameras(excludeBuiltin: false).map {
                        InlinePickerItem(id: $0.id, text: $0.name)
                    },
                    selectedId: model.getCameraId(vTuberWidget: vTuber)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    GrayTextView(text: model.getCameraPositionName(vTuberWidget: vTuber))
                }
            }
        }
        WidgetVTuberPickerView(model: model, vTuber: vTuber) {
            model.resetSelectedScene(changeScene: false)
        }
        if vTuber.type == .vrm {
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
            } header: {
                Text("Camera")
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
        WidgetSensitivityView(sensitivity: $vTuber.sensitivity)
            .onChange(of: vTuber.sensitivity) { _ in
                setEffectSettings()
            }
        if vTuber.type == .vrm {
            Section {
                HStack {
                    Text("Arms")
                    Slider(
                        value: $vTuber.armsAngle,
                        in: 20 ... 90,
                        step: 1.0
                    )
                    .onChange(of: vTuber.armsAngle) { _ in
                        setEffectSettings()
                    }
                }
            } header: {
                Text("Angles")
            }
        }
    }
}
