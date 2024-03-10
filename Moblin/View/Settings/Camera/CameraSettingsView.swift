import PhotosUI
import SwiftUI

struct CustomLutView: View {
    @EnvironmentObject var model: Model
    var lut: SettingsColorAppleLogLut

    private func submitName(value: String) {
        lut.name = value
        model.store()
        model.objectWillChange.send()
    }

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: lut.id) {
            return UIImage(data: data)!
        } else {
            return nil
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: NameEditView(
                    name: lut.name,
                    onSubmit: submitName
                )) {
                    TextItemView(name: String(localized: "Name"), value: lut.name)
                }
            }
            Section {
                if let image = loadImage() {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 1920 / 6, height: 1080 / 6)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Custom LUT")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct CameraSettingsLutsView: View {
    @EnvironmentObject var model: Model
    @State var selectedId: UUID
    @State var selectedImageItem: PhotosPickerItem?

    private func submitLut(id: UUID) {
        model.database.color!.lut = id
        model.store()
        model.lutUpdated()
        model.objectWillChange.send()
    }

    private func luts() -> [SettingsColorAppleLogLut] {
        return model.database.color!.diskLuts! + model.database.color!.bundledLuts
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.color!.lutEnabled
                }, set: { value in
                    model.database.color!.lutEnabled = value
                    model.lutEnabledUpdated()
                    model.store()
                })) {
                    Text("Enabled")
                }
            }
            Section {
                Picker("", selection: $selectedId) {
                    ForEach(luts()) { lut in
                        Text(lut.name)
                            .tag(lut.id)
                    }
                }
                .onChange(of: selectedId) { id in
                    submitLut(id: id)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                List {
                    ForEach(model.database.color!.diskLuts!) { lut in
                        NavigationLink(destination: CustomLutView(lut: lut)) {
                            Text(lut.name)
                        }
                        .tag(lut.id)
                    }
                    .onDelete(perform: { offsets in
                        for offset in offsets {
                            let lut = model.database.color!.diskLuts![offset]
                            model.imageStorage.remove(id: lut.id)
                        }
                        model.database.color!.diskLuts!.remove(atOffsets: offsets)
                        model.store()
                        model.objectWillChange.send()
                    })
                }
                PhotosPicker(selection: $selectedImageItem, matching: .images) {
                    HStack {
                        Spacer()
                        Text("Add")
                        Spacer()
                    }
                }
                .onChange(of: selectedImageItem) { imageItem in
                    imageItem?.loadTransferable(type: Data.self) { result in
                        switch result {
                        case let .success(data?):
                            DispatchQueue.main.async {
                                model.addLut(data: data)
                                selectedImageItem = nil
                            }
                        case .success(nil):
                            logger.error("widget: image is nil")
                        case let .failure(error):
                            logger.error("widget: image error: \(error)")
                        }
                    }
                }
            } header: {
                Text("Custom luts")
            }
        }
        .navigationTitle("LUT")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct CameraSettingsView: View {
    @EnvironmentObject var model: Model

    private func toCameraName(id: String, cameras: [Camera]) -> String {
        return cameras.first(where: { $0.id == id })?.name ?? ""
    }

    private func currentLut() -> String {
        if model.database.color!.lutEnabled {
            return model.getLogLutById(id: model.database.color!.lut)?.name ?? ""
        } else {
            return ""
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: ZoomSettingsView(speed: model.database.zoom.speed!)) {
                    Text("Zoom")
                }
                VideoStabilizationSettingsView()
                TapScreenToFocusSettingsView()
                Picker("Color space", selection: Binding(get: {
                    model.database.color!.space.rawValue
                }, set: { value in
                    model.database.color!.space = SettingsColorSpace(rawValue: value)!
                    model.store()
                    model.colorSpaceUpdated()
                    model.objectWillChange.send()
                })) {
                    ForEach(colorSpaces, id: \.self) { space in
                        Text(space)
                    }
                }
                NavigationLink(destination: CameraSettingsLutsView(selectedId: model.database.color!.lut)) {
                    HStack {
                        Text("LUT")
                        Spacer()
                        Text(currentLut())
                    }
                }
                Toggle("Mirror front camera on stream", isOn: Binding(get: {
                    model.database.mirrorFrontCameraOnStream!
                }, set: { value in
                    model.database.mirrorFrontCameraOnStream = value
                    model.store()
                    model.reattachCamera()
                }))
            } footer: {
                Text(
                    """
                    Mirror front camera on stream and rotate video 90 degrees in OBS for poor mans \
                    portrait streaming.
                    """
                )
            }
        }
        .navigationTitle("Camera")
        .toolbar {
            SettingsToolbar()
        }
    }
}
