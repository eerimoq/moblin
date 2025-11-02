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
                        image: widget.image(),
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
    @State var presentingCreateWizard: Bool = false

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
                presentingCreateWizard = true
                model.createWidgetWizard.reset()
            }
            .sheet(isPresented: $presentingCreateWizard) {
                NavigationStack {
                    WidgetWizardSettingsView(model: model,
                                             database: database,
                                             createWidgetWizard: model.createWidgetWizard,
                                             presentingCreateWizard: $presentingCreateWizard)
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
