import SwiftUI

struct WidgetWizardPngTuberSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var pngTuber: SettingsWidgetPngTuber
    @ObservedObject var videoSources: VideoSources
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    private func onCameraChange(cameraId: String) {
        pngTuber.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
    }

    var body: some View {
        Form {
            Section {
                WizardVideoSourcePickerView(
                    onChange: onCameraChange,
                    items: videoSources.all().map {
                        InlinePickerItem(id: $0.id, text: $0.name)
                    },
                    selectedId: model.getCameraId(pngTuberWidget: pngTuber)
                )
            }
            WidgetPngTuberPickerView(model: model, pngTuber: pngTuber)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(pngTuber.modelName.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
