import SwiftUI

struct QuickButtonLutsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                ForEach(model.allLuts()) { lut in
                    Toggle(isOn: Binding(get: {
                        lut.enabled!
                    }, set: { value in
                        lut.enabled = value
                        model.sceneUpdated()
                    })) {
                        Text(lut.name)
                    }
                }
            }
        }
        .navigationTitle("LUTs")
    }
}
