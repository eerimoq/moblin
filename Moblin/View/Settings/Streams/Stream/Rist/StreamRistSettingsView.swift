import SwiftUI

struct StreamRistSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Bonding", isOn: Binding(get: {
                    stream.rist!.bonding
                }, set: { value in
                    stream.rist!.bonding = value
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
            }
        }
        .navigationTitle("RIST")
        .toolbar {
            SettingsToolbar()
        }
    }
}
