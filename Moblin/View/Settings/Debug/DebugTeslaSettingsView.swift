import SwiftUI

struct DebugTeslaSettingsView: View {
    @EnvironmentObject var model: Model
    @State var privateKey: String

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "VIN"),
                    value: model.database.debug.tesla!.vin
                ) {
                    model.database.debug.tesla!.vin = $0.trim()
                }
            }
            Section {
                TextField("", text: $privateKey, axis: .vertical)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: privateKey) { _ in
                        model.database.debug.tesla!.privateKey = privateKey
                    }
            } header: {
                Text("Private key")
            }
        }
        .navigationTitle("Tesla")
    }
}
