import SwiftUI

private class SceneItem: ObservableObject, Identifiable {
    var id: UUID {
        scene.id
    }

    let scene: SettingsScene
    @Published var enabled: Bool

    init(scene: SettingsScene) {
        self.scene = scene
        enabled = false
    }
}

private struct SceneItemView: View {
    @Binding var scene: SceneItem

    var body: some View {
        Toggle(scene.scene.name, isOn: $scene.enabled)
    }
}

private struct WizardView: View {
    @EnvironmentObject var model: Model
    @State var manualName: Bool = false
    @State var name: String = "Browser"
    @State var type: SettingsWidgetType = .browser
    @State var scenes: [SceneItem] = []

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $type) {
                    ForEach(SettingsWidgetType.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .onChange(of: type) { _ in
                    if !manualName || name.isEmpty {
                        manualName = false
                        name = type.toString()
                    }
                }
            }
            Section {
                TextField("",
                          text: $name,
                          onEditingChanged: { _ in
                              manualName = true
                          })
                          .disableAutocorrection(true)
            } header: {
                Text("Name")
            }
            Section {
                ForEach($scenes) { scene in
                    SceneItemView(scene: scene)
                }
            } header: {
                Text("Scenes to add the widget to")
            }
            Section {
                HCenter {
                    Button {
                        let widget = SettingsWidget(name: name)
                        widget.type = type
                        model.database.widgets.append(widget)
                        for scene in scenes where scene.enabled {
                            logger.info("xxx should add widget to scene \(scene.scene.name)")
                        }
                        model.fixAlertMedias()
                        model.isPresentingWidgetWizard = false
                    } label: {
                        Text("Create")
                    }
                }
            }
        }
        .navigationTitle("Create widget wizard")
        .onAppear {
            scenes = model.enabledScenes.map { .init(scene: $0) }
        }
    }
}

private struct WidgetsSettingsItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        NavigationLink {
            WidgetSettingsView(database: database, widget: widget)
        } label: {
            Toggle(isOn: $widget.enabled) {
                HStack {
                    DraggableItemPrefixView()
                    IconAndTextView(
                        image: widgetImage(widget: widget),
                        text: widget.name,
                        longDivider: true
                    )
                    Spacer()
                }
            }
            .onChange(of: widget.enabled) { _ in
                model.sceneUpdated(attachCamera: model.isCaptureDeviceWidget(widget: widget))
            }
        }
    }
}

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            ForEach(database.widgets) { widget in
                WidgetsSettingsItemView(database: database, widget: widget)
            }
            .onMove { froms, to in
                database.widgets.move(fromOffsets: froms, toOffset: to)
            }
            .onDelete { offsets in
                database.widgets.remove(atOffsets: offsets)
                model.removeDeadWidgetsFromScenes()
                model.resetSelectedScene()
            }
            CreateButtonView {
                let name = makeUniqueName(name: SettingsWidget.baseName, existingNames: database.widgets)
                let widget = SettingsWidget(name: name)
                database.widgets.append(widget)
                model.fixAlertMedias()
                // model.isPresentingWidgetWizard = true
            }
            .sheet(isPresented: $model.isPresentingWidgetWizard) {
                NavigationStack {
                    WizardView()
                }
            }
        } header: {
            Text("Widgets")
        } footer: {
            VStack(alignment: .leading) {
                Text("A widget can be used in zero or more scenes.")
                Text("")
                SwipeLeftToDeleteHelpView(kind: String(localized: "a widget"))
            }
        }
    }
}
