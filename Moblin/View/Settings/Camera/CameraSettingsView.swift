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
            }
        }
        .navigationTitle("Camera")
        .toolbar {
            SettingsToolbar()
        }
    }
}
