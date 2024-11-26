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
                TextEditNavigationView(
                    title: String(localized: "Private key"),
                    value: model.database.debug.tesla!.privateKey
                ) {
                    model.database.debug.tesla!.privateKey = $0.trim()
                }
            }
        }
        .navigationTitle("Tesla")
    }
}
