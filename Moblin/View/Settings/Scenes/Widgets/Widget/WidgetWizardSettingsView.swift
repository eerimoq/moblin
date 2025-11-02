import SwiftUI

struct CreateWidgetWizardToolbar: ToolbarContent {
    @Binding var presentingCreateWizard: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                presentingCreateWizard = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct AddWidgetToSceneView: View {
    @ObservedObject var scene: SceneToAddWidgetTo

    var body: some View {
        Button {
            scene.enabled.toggle()
        } label: {
            HStack {
                Text(scene.scene.name)
                Spacer()
                if scene.enabled {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
        }
    }
}

private class SceneToAddWidgetTo: Identifiable, ObservableObject {
    let id: UUID = .init()
    let scene: SettingsScene
    @Published var enabled: Bool

    init(scene: SettingsScene, enabled: Bool) {
        self.scene = scene
        self.enabled = enabled
    }
}

struct WidgetWizardSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool
    @State private var scenesToAddWidgetTo: [SceneToAddWidgetTo] = []

    private func canCreate() -> Bool {
        return isValidName() == nil
    }

    private func isValidName() -> String? {
        if database.widgets.contains(where: { $0.name == createWidgetWizard.name }) {
            return String(localized: "The name '\(createWidgetWizard.name)' is already in use.")
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $createWidgetWizard.name)
                    .disableAutocorrection(true)
            } header: {
                Text("Name")
            } footer: {
                if let message = isValidName(), presentingCreateWizard {
                    Text(message)
                        .foregroundColor(.red)
                        .bold()
                }
            }
            Section {
                Picker("Type", selection: $createWidgetWizard.type) {
                    ForEach(widgetTypes, id: \.self) { type in
                        Text(type.toString())
                    }
                }
            }
            Section {
                ForEach(scenesToAddWidgetTo) { scene in
                    AddWidgetToSceneView(scene: scene)
                }
            } header: {
                Text("Scenes to add widget to")
            }
            Section {
                HCenter {
                    Button {
                        presentingCreateWizard = false
                        let name: String
                        if createWidgetWizard.name.isEmpty {
                            name = makeUniqueName(name: SettingsWidget.baseName, existingNames: database.widgets)
                        } else {
                            name = createWidgetWizard.name
                        }
                        let widget = SettingsWidget(name: name)
                        widget.type = createWidgetWizard.type
                        database.widgets.append(widget)
                        model.fixAlertMedias()
                        model.resetSelectedScene(changeScene: false, attachCamera: false)
                        for sceneToAddWidgetTo in scenesToAddWidgetTo where sceneToAddWidgetTo.enabled {
                            model.appendWidgetToScene(scene: sceneToAddWidgetTo.scene, widget: widget)
                        }
                    } label: {
                        Text("Create")
                    }
                    .disabled(!canCreate())
                }
            }
        }
        .navigationTitle("Create widget wizard")
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
        .onAppear {
            scenesToAddWidgetTo = database.scenes.map {
                SceneToAddWidgetTo(scene: $0, enabled: $0 === model.getSelectedScene())
            }
        }
    }
}
