import SwiftUI

struct WidgetWizardVTuberSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var vTuber: SettingsWidgetVTuber
    @ObservedObject var videoSources: VideoSources
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    private func onCameraChange(cameraId: String) {
        vTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
    }

    var body: some View {
        Form {
            Section {
                WizardVideoSourcePickerView(
                    onChange: onCameraChange,
                    items: videoSources.all().map {
                        InlinePickerItem(id: $0.id, text: $0.name)
                    },
                    selectedId: model.getCameraId(vTuberWidget: vTuber)
                )
            }
            WidgetVTuberPickerView(model: model, vTuber: vTuber)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(vTuber.modelName.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
