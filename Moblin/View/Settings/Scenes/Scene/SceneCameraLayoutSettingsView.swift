import SwiftUI

struct SceneCameraLayoutSettingsView: View {
    @EnvironmentObject var model: Model
    var scene: SettingsScene
    @State var cameraLayout: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $cameraLayout) {
                    ForEach(cameraLayouts, id: \.self) { layout in
                        Text(layout)
                    }
                }
                .onChange(of: cameraLayout) { layout in
                    scene.cameraLayout = SettingsSceneCameraLayout(rawValue: layout)!
                    model.sceneUpdated(store: true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("The Picture in Picture layout is experimental and does not work.")
            }
        }
        .navigationTitle("Layout")
        .toolbar {
            SettingsToolbar()
        }
    }
}
