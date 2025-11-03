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
        .foregroundColor(.primary)
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

private struct SelectScenesView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool
    @State private var scenesToAddWidgetTo: [SceneToAddWidgetTo] = []

    private func create() {
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
    }

    var body: some View {
        Form {
            Section {
                ForEach(scenesToAddWidgetTo) { scene in
                    AddWidgetToSceneView(scene: scene)
                }
            }
            Section {
                Button {
                    create()
                } label: {
                    HCenter {
                        Text("Create")
                    }
                }
            }
        }
        .navigationTitle("Scenes to add the widget to")
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

struct WidgetWizardSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    private func isValidName() -> String? {
        if database.widgets.contains(where: { $0.name == createWidgetWizard.name }) {
            return String(localized: "The name '\(createWidgetWizard.name)' is already in use.")
        }
        return nil
    }

    private func canGoNext() -> Bool {
        return isValidName() == nil
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $createWidgetWizard.name)
                    .disableAutocorrection(true)
            } header: {
                Text("Name")
            } footer: {
                if let message = isValidName() {
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
            } footer: {
                Text(createWidgetWizard.type.description())
            }
            Section {
                NavigationLink {
                    SelectScenesView(model: model,
                                     database: database,
                                     createWidgetWizard: createWidgetWizard,
                                     presentingCreateWizard: $presentingCreateWizard)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(!canGoNext())
            }
        }
        .navigationTitle("Create widget wizard")
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
