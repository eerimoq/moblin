import SwiftUI

struct WidgetSceneSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var selectedSceneId: UUID

    var body: some View {
        Section {
            Picker("", selection: $selectedSceneId) {
                ForEach(model.database.scenes) { scene in
                    Text(scene.name)
                        .tag(scene.id)
                }
            }
            .onChange(of: selectedSceneId) { sceneId in
                widget.scene!.sceneId = sceneId
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Scene")
        }
    }
}
