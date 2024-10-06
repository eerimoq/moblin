import PhotosUI
import SwiftUI

struct CustomLutView: View {
    @EnvironmentObject var model: Model
    var lut: SettingsColorLut
    @State var name: String

    private func submitName(value: String) {
        model.setLutName(lut: lut, name: value)
        name = value
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
                NavigationLink {
                    NameEditView(name: name, onSubmit: submitName)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: name)
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
    }
}

struct CameraSettingsLutsView: View {
    @EnvironmentObject var model: Model
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.color!.bundledLuts) { lut in
                        Text(lut.name)
                            .tag(lut.id)
                    }
                }
            } header: {
                Text("Bundled")
            }
            Section {
                List {
                    ForEach(model.database.color!.diskLuts!) { lut in
                        NavigationLink {
                            CustomLutView(lut: lut, name: lut.name)
                        } label: {
                            Text(lut.name)
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
                Text("My LUTs")
            } footer: {
                Text("Add your own LUTs.")
            }
        }
        .navigationTitle("LUTs")
    }
}

struct CameraSettingsAppleLogLutView: View {
    @EnvironmentObject var model: Model
    @State var selectedId: UUID

    private func submitLut(id: UUID) {
        model.database.color!.lut = id
        model.lutUpdated()
        model.objectWillChange.send()
    }

    private func luts() -> [SettingsColorLut] {
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
    }
}

struct CameraSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                if model.database.showAllSettings! {
                    NavigationLink {
                        ZoomSettingsView(speed: model.database.zoom.speed!)
                    } label: {
                        Text("Zoom")
                    }
                }
                VideoStabilizationSettingsView(mode: model.database.videoStabilizationMode.toString())
                if model.database.showAllSettings! {
                    TapScreenToFocusSettingsView()
                }
                MirrorFrontCameraOnStreamView()
            } footer: {
                Text(
                    "\"Mirror front camera on stream\" is only supported when streaming in landscape, not portrait."
                )
            }
            if model.database.showAllSettings! {
                if model.supportsAppleLog {
                    Section {
                        Picker("Color space", selection: Binding(get: {
                            model.database.color!.space.rawValue
                        }, set: { value in
                            model.database.color!.space = SettingsColorSpace(rawValue: value)!
                            model.colorSpaceUpdated()
                            model.objectWillChange.send()
                        })) {
                            ForEach(colorSpaces, id: \.self) { space in
                                Text(space)
                            }
                        }
                        .disabled(model.isLive || model.isRecording)
                        NavigationLink {
                            CameraSettingsAppleLogLutView(
                                selectedId: model.database.color!.lut
                            )
                        } label: {
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
                    NavigationLink {
                        CameraSettingsLutsView()
                    } label: {
                        Text("LUTs")
                    }
                } footer: {
                    Text("LUTs modifies image colors when applied.")
                }
            }
        }
        .navigationTitle("Camera")
    }
}
