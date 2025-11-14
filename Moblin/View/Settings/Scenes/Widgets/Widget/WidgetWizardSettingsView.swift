import SwiftUI

func basicWidgetSettingsTitle(_ createWidgetWizard: CreateWidgetWizard) -> String {
    return String(localized: "Basic \(createWidgetWizard.type.toString()) widget settings")
}

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
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
        }
        .foregroundStyle(.primary)
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
        let widget = createWidgetWizard.widget
        widget.type = createWidgetWizard.type
        widget.name = name
        database.widgets.append(widget)
        model.fixAlertMedias()
        model.resetSelectedScene(changeScene: false, attachCamera: false)
        for sceneToAddWidgetTo in scenesToAddWidgetTo where sceneToAddWidgetTo.enabled {
            model.appendWidgetToScene(scene: sceneToAddWidgetTo.scene, widget: widget)
        }
        if widget.type == .text {
            model.textWidgetTextChanged(widget: widget)
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
                TextButtonView("Create") {
                    create()
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

struct WidgetWizardSelectScenesNavigationView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Section {
            NavigationLink {
                SelectScenesView(model: model,
                                 database: database,
                                 createWidgetWizard: createWidgetWizard,
                                 presentingCreateWizard: $presentingCreateWizard)
            } label: {
                WizardNextButtonView()
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
                TextField("My widget", text: $createWidgetWizard.name)
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
                    switch createWidgetWizard.type {
                    case .text:
                        WidgetWizardTextSettingsView(model: model,
                                                     database: database,
                                                     createWidgetWizard: createWidgetWizard,
                                                     text: createWidgetWizard.widget.text,
                                                     presentingCreateWizard: $presentingCreateWizard)
                    case .browser:
                        WidgetWizardBrowserSettingsView(model: model,
                                                        database: database,
                                                        createWidgetWizard: createWidgetWizard,
                                                        browser: createWidgetWizard.widget.browser,
                                                        presentingCreateWizard: $presentingCreateWizard)
                    case .videoSource:
                        WidgetWizardVideoSourceSettingsView(model: model,
                                                            database: database,
                                                            createWidgetWizard: createWidgetWizard,
                                                            videoSource: createWidgetWizard.widget.videoSource,
                                                            presentingCreateWizard: $presentingCreateWizard)
                    case .image:
                        WidgetWizardImageSettingsView(model: model,
                                                      database: database,
                                                      widget: createWidgetWizard.widget,
                                                      createWidgetWizard: createWidgetWizard,
                                                      presentingCreateWizard: $presentingCreateWizard)
                    case .vTuber:
                        WidgetWizardVTuberSettingsView(model: model,
                                                       database: database,
                                                       vTuber: createWidgetWizard.widget.vTuber,
                                                       createWidgetWizard: createWidgetWizard,
                                                       presentingCreateWizard: $presentingCreateWizard)
                    case .pngTuber:
                        WidgetWizardPngTuberSettingsView(model: model,
                                                         database: database,
                                                         pngTuber: createWidgetWizard.widget.pngTuber,
                                                         createWidgetWizard: createWidgetWizard,
                                                         presentingCreateWizard: $presentingCreateWizard)
                    default:
                        SelectScenesView(model: model,
                                         database: database,
                                         createWidgetWizard: createWidgetWizard,
                                         presentingCreateWizard: $presentingCreateWizard)
                    }
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
