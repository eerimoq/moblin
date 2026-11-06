import SwiftUI

struct WidgetSceneSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var scene: SettingsWidgetScene

    var body: some View {
        Section {
            Picker("", selection: $scene.sceneId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.selectableScenes(widget: widget)) { selectableScene in
                    SceneNameView(scene: selectableScene)
                        .tag(selectableScene.id as UUID?)
                }
            }
            .onChange(of: scene.sceneId) { _ in
                model.resetSelectedScene(changeScene: false)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Scene")
        }
    }
}
