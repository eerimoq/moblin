import SwiftUI

private struct PickerView: View {
    var onChange: (String) -> Void
    var items: [InlinePickerItem]
    @State var selectedId: String

    var body: some View {
        Picker("Video source", selection: $selectedId) {
            ForEach(items) { item in
                Text(item.text)
                    .tag(item.id)
            }
            if !items.contains(where: { $0.id == selectedId }) {
                Text("Unknown 😢")
                    .tag(selectedId)
            }
        }
        .onChange(of: selectedId) { item in
            onChange(item)
        }
    }
}

struct WidgetWizardVideoSourceSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @ObservedObject var videoSource: SettingsWidgetVideoSource
    @Binding var presentingCreateWizard: Bool

    private func onCameraChange(cameraId: String) {
        videoSource.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
    }

    var body: some View {
        Form {
            Section {
                PickerView(
                    onChange: onCameraChange,
                    items: model.listCameraPositions(excludeBuiltin: false).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(videoSourceWidget: videoSource)
                )
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
