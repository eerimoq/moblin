import PhotosUI
import SwiftUI

struct CustomLutView: View {
    @EnvironmentObject var model: Model
    var lut: SettingsColorAppleLogLut

    private func submitName(value: String) {
        model.setLutName(lut: lut, name: value)
        model.objectWillChange.send()
    }

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: lut.id) {
            return UIImage(data: data)!
        } else {
            return nil
        }
    }

    func onSystemImageName(name: String) {
        guard let button = model.findLutButton(lut: lut) else {
            return
        }
        button.systemImageNameOn = name
        button.systemImageNameOff = name
        model.store()
        model.objectWillChange.send()
        model.updateButtonStates()
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
                if let button = model.findLutButton(lut: lut) {
                    NavigationLink(destination: ButtonImagePickerSettingsView(
                        title: String(localized: "Icon"),
                        selectedImageSystemName: button.systemImageNameOn,
                        onChange: onSystemImageName
                    )) {
                        ImageItemView(name: String(localized: "Icon"), image: button.systemImageNameOn)
                    }
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
    @State var selectedImageItem: PhotosPickerItem?

    private func getIcon(lut: SettingsColorAppleLogLut) -> String {
        return model.findLutButton(lut: lut)?.systemImageNameOn ?? "camera.filters"
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.color!.bundledLuts) { lut in
                        HStack {
                            Image(systemName: getIcon(lut: lut))
                            Text(lut.name)
                        }
                        .tag(lut.id)
                    }
                }
            } header: {
                Text("Bundled")
            }
            Section {
                List {
                    ForEach(model.database.color!.diskLuts!) { lut in
                        NavigationLink(destination: CustomLutView(lut: lut)) {
                            HStack {
                                Image(systemName: getIcon(lut: lut))
                                Text(lut.name)
                            }
                        }
                        .tag(lut.id)
                    }
                    .onDelete(perform: { offsets in
                        model.removeLut(offsets: offsets)
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
                Text("Custom")
            } footer: {
                Text("Add your own LUTs.")
            }
        }
        .navigationTitle("LUTs")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct CameraSettingsAppleLogLutView: View {
    @EnvironmentObject var model: Model
    @State var selectedId: UUID

    private func submitLut(id: UUID) {
        model.database.color!.lut = id
        model.store()
        model.lutUpdated()
        model.objectWillChange.send()
    }

    private func luts() -> [SettingsColorAppleLogLut] {
        return model.database.color!.bundledLuts + model.database.color!.diskLuts!
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
            } footer: {
                Text("If enabled, selected LUT is applied when the Apple Log color space is used.")
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
        }
        .navigationTitle("Apple Log LUT")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct CameraSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: ZoomSettingsView(speed: model.database.zoom.speed!)) {
                    Text("Zoom")
                }
                VideoStabilizationSettingsView()
                TapScreenToFocusSettingsView()
            }
            if model.supportsAppleLog {
                Section {
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
                    .disabled(model.isLive || model.isRecording)
                    NavigationLink(destination: CameraSettingsAppleLogLutView(selectedId: model.database
                            .color!
                            .lut))
                    {
                        Text("Apple Log LUT")
                    }
                } footer: {
                    Text("The Apple Log LUT is only applied when the Apple Log color space is selected.")
                }
            } else {
                Section {
                    Picker("Color space", selection: Binding(get: {
                        model.database.color!.space.rawValue
                    }, set: { value in
                        model.database.color!.space = SettingsColorSpace(rawValue: value)!
                        model.store()
                        model.colorSpaceUpdated()
                        model.objectWillChange.send()
                    })) {
                        ForEach(colorSpaces.filter { $0 != "Apple Log" }, id: \.self) { space in
                            Text(space)
                        }
                    }
                    .disabled(model.isLive || model.isRecording)
                }
            }
            Section {
                NavigationLink(destination: CameraSettingsLutsView()) {
                    Text("LUTs")
                }
            } footer: {
                Text("LUTs modifies image colors when applied.")
            }
        }
        .navigationTitle("Camera")
        .toolbar {
            SettingsToolbar()
        }
    }
}
