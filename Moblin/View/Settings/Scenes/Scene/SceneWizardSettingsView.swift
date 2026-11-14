import SwiftUI

private struct SelectWidgetView: View {
    @ObservedObject var createSceneWizard: CreateSceneWizard
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Button {
            if createSceneWizard.widgetIds.contains(widget.id) {
                createSceneWizard.widgetIds.remove(widget.id)
            } else {
                createSceneWizard.widgetIds.insert(widget.id)
            }
        } label: {
            HStack {
                IconAndTextView(image: widget.image(), text: widget.name)
                Spacer()
                if createSceneWizard.widgetIds.contains(widget.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct SelectWidgetsView: View {
    let model: Model
    @ObservedObject var database: Database
    let createSceneWizard: CreateSceneWizard
    @Binding var presentingCreateWizard: Bool
    let onCreated: (SettingsScene) -> Void

    var body: some View {
        Form {
            if !database.widgets.isEmpty {
                Section {
                    ForEach(database.widgets) { widget in
                        SelectWidgetView(createSceneWizard: createSceneWizard, widget: widget)
                    }
                }
            }
            Section {
                TextButtonView("Create") {
                    presentingCreateWizard = false
                    onCreated(model.createScene())
                }
            }
        }
        .navigationTitle("Widgets to add to the scene")
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}

private struct SceneWizardSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createSceneWizard: CreateSceneWizard
    @ObservedObject var videoSources: VideoSources
    @Binding var presentingCreateWizard: Bool
    let onCreated: (SettingsScene) -> Void

    private func isValidName() -> String? {
        if database.scenes.contains(where: { $0.name == createSceneWizard.name }) {
            return String(localized: "The name '\(createSceneWizard.name)' is already in use.")
        }
        return nil
    }

    private func onCameraChange(cameraId: String) {
        createSceneWizard.scene
            .updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
    }

    var body: some View {
        Form {
            Section {
                TextField(SettingsScene.baseName, text: $createSceneWizard.name)
                    .disableAutocorrection(true)
            } header: {
                Text("Name")
            } footer: {
                if let message = isValidName() {
                    Text(message)
                        .foregroundStyle(.red)
                        .bold()
                }
            }
            Section {
                WizardVideoSourcePickerView(
                    onChange: onCameraChange,
                    items: videoSources.all().map {
                        InlinePickerItem(id: $0.id, text: $0.name)
                    },
                    selectedId: model.getCameraId(scene: createSceneWizard.scene)
                )
            }
            Section {
                NavigationLink {
                    SelectWidgetsView(model: model,
                                      database: database,
                                      createSceneWizard: createSceneWizard,
                                      presentingCreateWizard: $presentingCreateWizard,
                                      onCreated: onCreated)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(isValidName() != nil)
            }
        }
        .navigationTitle("Create scene wizard")
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}

struct SceneWizardSheetView: View {
    let model: Model
    let database: Database
    @Binding var presentingCreateWizard: Bool
    var onCreated: (SettingsScene) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            SceneWizardSettingsView(model: model,
                                    database: database,
                                    createSceneWizard: model.createSceneWizard,
                                    videoSources: model.videoSources,
                                    presentingCreateWizard: $presentingCreateWizard,
                                    onCreated: onCreated)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
