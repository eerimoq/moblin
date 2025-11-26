import SwiftUI

private struct LutView: View {
    let model: Model
    @ObservedObject var lut: SettingsColorLut

    var body: some View {
        Toggle(lut.name, isOn: $lut.enabled)
            .onChange(of: lut.enabled) { _ in
                model.sceneUpdated(updateRemoteScene: false)
            }
    }
}

struct QuickButtonLutsView: View {
    let model: Model
    @ObservedObject var color: SettingsColor

    var body: some View {
        Form {
            Section {
                ForEach(model.allLuts()) { lut in
                    LutView(model: model, lut: lut)
                }
            }
            Section {
                NavigationLink {
                    CameraSettingsLutsView(color: color)
                } label: {
                    Label("LUTs", systemImage: "camera")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("LUTs")
    }
}
