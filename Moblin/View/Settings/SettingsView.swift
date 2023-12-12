import SwiftUI

let settingsHalfWidth = 350.0

enum SettingsLayout {
    case full
    case left
    case right
}

struct SettingsLayoutMenuItem {
    var layout: SettingsLayout
    var image: String
    var text: String
}

private let layoutMenuItems = [
    SettingsLayoutMenuItem(
        layout: .right,
        image: "rectangle.righthalf.filled",
        text: "Right"
    ),
    SettingsLayoutMenuItem(
        layout: .left,
        image: "rectangle.lefthalf.filled",
        text: "Left"
    ),
    SettingsLayoutMenuItem(layout: .full, image: "rectangle.fill", text: "Full"),
]

struct SettingsToolbar: ToolbarContent {
    @EnvironmentObject var model: Model

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Picker("", selection: $model.settingsLayout) {
                    ForEach(layoutMenuItems, id: \.layout) { item in
                        Image(systemName: item.image)
                    }
                }
                .padding([.trailing], -10)
                Button(action: {
                    model.showingSettings = false
                }, label: {
                    Text("Close")
                })
            }
        }
    }
}

struct QuickSettingsToolbar: ToolbarContent {
    let done: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                done()
            }, label: {
                Text("Close")
            })
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: Model

    private func onChangeBackCamera(camera: String) {
        model.database.backCameraType = model.backCameras.first { $0.name == camera }!.type
        model.sceneUpdated()
    }

    private func onChangeFrontCamera(camera: String) {
        model.database.frontCameraType = model.frontCameras.first { $0.name == camera }!.type
        model.sceneUpdated()
    }

    private func toCameraName(value: SettingsCameraType, cameras: [Camera]) -> String {
        return cameras.first(where: { $0.type == value })?.name ?? ""
    }

    var body: some View {
        Form {
            if model.isLive {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(
                            "Settings that would stop the stream are disabled when live."
                        )
                    }
                }
            }
            Section {
                NavigationLink(destination: StreamsSettingsView()) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView()) {
                    Text("Scenes")
                }
                NavigationLink(
                    destination: LocalOverlaysSettingsView()
                ) {
                    Text("Local overlays")
                }
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Back camera"),
                    onChange: onChangeBackCamera,
                    footers: [
                        """
                        The ultra wide camera does not perform well in low light conditions. Likewise, the \
                        auto cameras do not perform well when zoom is 0.5-1.0x since the ultra wide camera \
                        will be used.
                        """,
                        "",
                        """
                        Auto cameras use more energy as multiple cameras are powered on, even if only \
                        one is used at a time. This allows the phone to quickly change camera when zooming.
                        """,
                    ],
                    items: model.backCameras.map { $0.name },
                    selected: toCameraName(value: model.database.backCameraType!, cameras: model.backCameras)
                )) {
                    TextItemView(
                        name: String(localized: "Back camera"),
                        value: toCameraName(value: model.database.backCameraType!, cameras: model.backCameras)
                    )
                }
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Front camera"),
                    onChange: onChangeFrontCamera,
                    items: model.frontCameras.map { $0.name },
                    selected: toCameraName(
                        value: model.database.frontCameraType!,
                        cameras: model.frontCameras
                    )
                )) {
                    TextItemView(
                        name: String(localized: "Front camera"),
                        value: toCameraName(
                            value: model.database.frontCameraType!,
                            cameras: model.frontCameras
                        )
                    )
                }
                NavigationLink(destination: ZoomSettingsView(speed: model.database.zoom.speed!)) {
                    Text("Zoom")
                }
                VideoStabilizationSettingsView()
                NavigationLink(
                    destination: BitratePresetsSettingsView()
                ) {
                    Text("Bitrate presets")
                }
                TapScreenToFocusSettingsView()
                Toggle("Battery percentage", isOn: Binding(get: {
                    model.database.batteryPercentage!
                }, set: { value in
                    model.database.batteryPercentage = value
                    model.store()
                }))
            }
            Section {
                NavigationLink(destination: CosmeticsSettingsView(
                )) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Cosmetics")
                    }
                }
            }
            Section {
                NavigationLink(
                    destination: HelpAndSupportSettingsView()
                ) {
                    Text("Help & support")
                }
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
                NavigationLink(
                    destination: DebugSettingsView(srtOverheadBandwidth: Float(model
                            .database.debug!.srtOverheadBandwidth!))
                ) {
                    Text("Debug")
                }
            }
            Section {
                NavigationLink(
                    destination: ImportExportSettingsView()
                ) {
                    Text("Import and export settings")
                }
            }
            Section {
                ResetSettingsView()
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            SettingsToolbar()
        }
    }
}
