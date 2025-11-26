import PhotosUI
import SwiftUI

struct CustomLutView: View {
    @EnvironmentObject var model: Model
    let lut: SettingsColorLut
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
                    NameEditView(name: $name)
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
    @ObservedObject var color: SettingsColor
    @State var showPicker = false

    private func onUrl(url: URL) {
        model.addLutCube(url: url)
    }

    var body: some View {
        Section {
            List {
                ForEach(color.diskLutsCube) { lut in
                    CustomLutView(lut: lut, name: lut.name)
                        .tag(lut.id)
                }
                .onDelete { offsets in
                    model.removeLutCube(offsets: offsets)
                }
            }
            TextButtonView("Add") {
                showPicker = true
                model.onDocumentPickerUrl = onUrl
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
    @ObservedObject var color: SettingsColor
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Section {
            List {
                ForEach(color.diskLutsPng) { lut in
                    CustomLutView(lut: lut, name: lut.name)
                        .tag(lut.id)
                }
                .onDelete { offsets in
                    model.removeLutPng(offsets: offsets)
                }
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

struct CameraSettingsLutsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var color: SettingsColor
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(color.bundledLuts) { lut in
                        Text(lut.name)
                            .tag(lut.id)
                    }
                }
            } header: {
                Text("Bundled")
            }
            CameraSettingsCubeLutsView(color: color)
            CameraSettingsPngLutsView(color: color)
        }
        .navigationTitle("LUTs")
    }
}

private struct CameraSettingsAppleLogLutView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var color: SettingsColor

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $color.lutEnabled) {
                    Text("Enabled")
                }
                .onChange(of: color.lutEnabled) { _ in
                    model.lutEnabledUpdated()
                }
            } footer: {
                Text("If enabled, selected LUT is applied when the Apple Log color space is used.")
            }
            Section {
                Picker("", selection: $color.lut) {
                    ForEach(model.allLuts()) { lut in
                        Text(lut.name)
                            .tag(lut.id)
                    }
                }
                .onChange(of: color.lut) { _ in
                    model.lutUpdated()
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
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    @ObservedObject var color: SettingsColor

    var body: some View {
        Form {
            if stream !== fallbackStream {
                Section {
                    NavigationLink {
                        StreamVideoSettingsView(database: database, stream: stream)
                    } label: {
                        Label("Video", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                if database.showAllSettings {
                    NavigationLink {
                        ZoomSettingsView(zoom: database.zoom)
                    } label: {
                        Text("Zoom")
                    }
                }
                VideoStabilizationSettingsView(mode: database.videoStabilizationMode)
                if database.showAllSettings {
                    FixedHorizonView(database: database)
                }
                MirrorFrontCameraOnStreamView(model: model, database: database)
                SelfieStickDoesNotWorkView(database: database, selfieStick: database.selfieStick)
            }
            if database.showAllSettings {
                Section {
                    TapScreenToFocusSettingsView(model: model, database: database)
                } footer: {
                    Text("⚠️ Does not work well when interactive chat is enabled.")
                }
            }
            if database.showAllSettings {
                Section {
                    CameraControlsView(database: database)
                } footer: {
                    Text("⚠️ Hijacks volume buttons. You can only change volume in Control Center when enabled.")
                }
            }
            if database.showAllSettings {
                if model.supportsAppleLog {
                    Section {
                        Picker("Color space", selection: $color.space) {
                            ForEach(colorSpaces, id: \.self) { space in
                                Text(space.rawValue)
                            }
                        }
                        .onChange(of: color.space) { _ in
                            model.colorSpaceUpdated()
                        }
                        .disabled(model.isLive || model.isRecording)
                        NavigationLink {
                            CameraSettingsAppleLogLutView(color: color)
                        } label: {
                            Text("Apple Log LUT")
                        }
                    } footer: {
                        Text("The Apple Log LUT is only applied when the Apple Log color space is selected.")
                    }
                } else {
                    Section {
                        Picker("Color space", selection: $color.space) {
                            ForEach(colorSpaces.filter { $0 != .appleLog }, id: \.self) { space in
                                Text(space.rawValue)
                            }
                        }
                        .onChange(of: color.space) { _ in
                            model.colorSpaceUpdated()
                        }
                        .disabled(model.isLive || model.isRecording)
                    }
                }
                Section {
                    NavigationLink {
                        CameraSettingsLutsView(color: color)
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
