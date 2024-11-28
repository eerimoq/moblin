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
            Section {
                Button {
                    model.teslaFlashLights()
                } label: {
                    HStack {
                        Spacer()
                    Text("Flash lights")
                        Spacer()
                    }
                }
            }
            Section {
                Button {
                    model.teslaHonk()
                } label: {
                    HStack {
                        Spacer()
                    Text("Honk")
                        Spacer()
                    }
                }
            }
            Section {
                Button {
                    model.teslaOpenTrunk()
                } label: {
                    HStack {
                        Spacer()
                    Text("Open trunk")
                        Spacer()
                    }
                }
            }
            Section {
                Button {
                    model.teslaCloseTrunk()
                } label: {
                    HStack {
                        Spacer()
                        Text("Close trunk")
                        Spacer()
                    }
                }
            }
            Section {
                Button {
                    model.teslaGetChargeState()
                } label: {
                    HStack {
                        Spacer()
                        Text("Get charge info")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Tesla")
    }
}
