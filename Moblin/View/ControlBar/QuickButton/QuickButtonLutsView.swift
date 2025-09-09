import SwiftUI

struct QuickButtonLutsView: View {
    let model: Model

    var body: some View {
        Form {
            Section {
                ForEach(model.allLuts()) { lut in
                    Toggle(isOn: Binding(get: {
                        lut.enabled
                    }, set: {
                        lut.enabled = $0
                        model.sceneUpdated(updateRemoteScene: false)
                    })) {
                        Text(lut.name)
                    }
                }
            }
        }
        .navigationTitle("LUTs")
    }
}
