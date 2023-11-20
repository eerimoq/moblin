import SwiftUI

struct SceneCameraOrientationSettingsView: View {
    @EnvironmentObject var model: Model
    var title: String
    var scene: SettingsScene
    @State var cameraType: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $cameraType) {
                    ForEach(cameraTypes, id: \.self) { cameraType in
                        Text(cameraType)
                    }
                }
                .onChange(of: cameraType) { cameraType in
                    scene.cameraType = SettingsSceneCameraType(rawValue: cameraType)!
                    model.sceneUpdated(store: true)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
