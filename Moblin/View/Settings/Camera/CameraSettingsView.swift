import SwiftUI

struct CameraSettingsView: View {
    @EnvironmentObject var model: Model

    private func onChangeBackCamera(id: String) {
        model.database.backCameraId = id
        model.sceneUpdated()
    }

    private func onChangeFrontCamera(id: String) {
        model.database.frontCameraId = id
        model.sceneUpdated()
    }

    private func toCameraName(id: String, cameras: [Camera]) -> String {
        return cameras.first(where: { $0.id == id })?.name ?? ""
    }

    private func submitLut(id: String) {
        model.database.color!.lut = UUID(uuidString: id)!
        model.store()
        model.lutUpdated()
        model.objectWillChange.send()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Back camera"),
                    onChange: onChangeBackCamera,
                    footers: [
                        String(localized: """
                        The ultra wide camera does not perform well in low light conditions. Likewise, the \
                        auto cameras do not perform well when zoom is 0.5-1.0x since the ultra wide camera \
                        will be used.
                        """),
                        "",
                        String(localized: """
                        Auto cameras use more energy as multiple cameras are powered on, even if only \
                        one is used at a time. This allows the phone to quickly change camera when zooming.
                        """),
                    ],
                    items: model.backCameras.map { InlinePickerItem(id: $0.id, text: $0.name) },
                    selectedId: model.database.backCameraId!
                )) {
                    TextItemView(
                        name: String(localized: "Back camera"),
                        value: toCameraName(id: model.database.backCameraId!, cameras: model.backCameras)
                    )
                }
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Front camera"),
                    onChange: onChangeFrontCamera,
                    items: model.frontCameras.map { InlinePickerItem(id: $0.id, text: $0.name) },
                    selectedId: model.database.frontCameraId!
                )) {
                    TextItemView(
                        name: String(localized: "Front camera"),
                        value: toCameraName(
                            id: model.database.frontCameraId!,
                            cameras: model.frontCameras
                        )
                    )
                }
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
                NavigationLink(destination: InlinePickerView(
                    title: "LUT",
                    onChange: submitLut,
                    items: model.database.color!.bundledLuts.map { lut in
                        InlinePickerItem(id: lut.id.uuidString, text: lut.name)
                    },
                    selectedId: model.database.color!.lut.uuidString
                )) {
                    Toggle(isOn: Binding(get: {
                        model.database.color!.lutEnabled
                    }, set: { value in
                        model.database.color!.lutEnabled = value
                        model.lutEnabledUpdated()
                        model.store()
                    })) {
                        HStack {
                            Text("LUT")
                            Spacer()
                            Text(model.getLogLutById(id: model.database.color!.lut)?.name ?? "")
                        }
                    }
                }
            }
        }
        .navigationTitle("Camera")
        .toolbar {
            SettingsToolbar()
        }
    }
}
