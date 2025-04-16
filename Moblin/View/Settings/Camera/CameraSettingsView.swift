import PhotosUI
import SwiftUI

struct CustomLutView: View {
    @EnvironmentObject var model: Model
    var lut: SettingsColorLut
    @State var name: String

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: lut.id) {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        NameEditView(name: $name)
                    } label: {
                        TextItemView(name: String(localized: "Name"), value: name)
                    }
                    .onChange(of: name) { name in
                        model.setLutName(lut: lut, name: name)
                    }
                }
                Section {
                    if let image = loadImage() {
                        HCenter {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 1920 / 6, height: 1080 / 6)
                        }
                    }
                }
            }
            .navigationTitle("Custom LUT")
        } label: {
            Text(name)
        }
    }
}

private struct CameraSettingsCubeLutsView: View {
    @EnvironmentObject var model: Model
    @State var showPicker = false

    private func onUrl(url: URL) {
        model.addLutCube(url: url)
    }

    var body: some View {
        Section {
            List {
                ForEach(model.database.color!.diskLutsCube!) { lut in
                    CustomLutView(lut: lut, name: lut.name)
                        .tag(lut.id)
                }
                .onDelete(perform: { offsets in
                    model.removeLutCube(offsets: offsets)
                    model.objectWillChange.send()
                })
            }
            Button {
                showPicker = true
                model.onDocumentPickerUrl = onUrl
            } label: {
                HCenter {
                    Text("Add")
                }
            }
            .sheet(isPresented: $showPicker) {
                AlertPickerView(type: .item)
            }
        } header: {
            Text("My .cube LUTs")
        }
    }
}

private struct CameraSettingsPngLutsView: View {
    @EnvironmentObject var model: Model
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Section {
            List {
                ForEach(model.database.color!.diskLutsPng!) { lut in
                    CustomLutView(lut: lut, name: lut.name)
                        .tag(lut.id)
                }
                .onDelete(perform: { offsets in
                    model.removeLutPng(offsets: offsets)
                    model.objectWillChange.send()
                })
            }
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                HCenter {
                    Text("Add")
                }
            }
            .onChange(of: selectedImageItem) { imageItem in
                imageItem?.loadTransferable(type: Data.self) { result in
                    switch result {
                    case let .success(data?):
                        DispatchQueue.main.async {
                            model.addLutPng(data: data)
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
            Text("My .png LUTs")
        }
    }
}

private struct CameraSettingsLutsView: View {
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
            CameraSettingsCubeLutsView()
            CameraSettingsPngLutsView()
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
                    ForEach(model.allLuts()) { lut in
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
                NavigationLink {
                    StreamVideoSettingsView(
                        stream: model.stream,
                        codec: model.stream.codec.rawValue,
                        bitrate: model.stream.bitrate,
                        resolution: model.stream.resolution.rawValue,
                        fps: String(model.stream.fps)
                    )
                } label: {
                    IconAndTextView(
                        image: "dot.radiowaves.left.and.right",
                        text: String(localized: "Video")
                    )
                }
            } header: {
                Text("Shortcut")
            }
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
                    Toggle("Camera controls", isOn: Binding(get: {
                        model.database.cameraControlsEnabled!
                    }, set: { value in
                        model.database.cameraControlsEnabled = value
                        model.setCameraControlsEnabled()
                    }))
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
