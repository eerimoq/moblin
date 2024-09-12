import SwiftUI

struct QuickButtonLutsView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void

    var body: some View {
        Form {
            Section {
                ForEach(model.allLuts()) { lut in
                    Toggle(isOn: Binding(get: {
                        lut.enabled!
                    }, set: { value in
                        lut.enabled = value
                        model.sceneUpdated(store: false)
                    })) {
                        Text(lut.name)
                    }
                }
            }
        }
        .navigationTitle("LUTs")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}
