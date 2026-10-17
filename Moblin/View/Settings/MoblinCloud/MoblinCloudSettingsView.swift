import SwiftUI

struct MoblinCloudSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var moblinCloud: SettingsMoblinCloud

    var body: some View {
        Form {
            Section {
                Text("""
                Let viewers interact with your stream from your page at https://moblin.app. \
                Sign in at https://moblin.app/dashboard to get your secret key.
                """)
            }
            Section {
                Toggle("Enabled", isOn: $moblinCloud.enabled)
                    .onChange(of: moblinCloud.enabled) { _ in
                        model.reloadMoblinCloud()
                    }
                TextEditNavigationView(
                    title: String(localized: "Secret key"),
                    value: moblinCloud.key,
                    onSubmit: {
                        moblinCloud.key = $0
                        model.reloadMoblinCloud()
                    },
                    sensitive: true
                )
            } footer: {
                Text("Keep the secret key to yourself.")
            }
            Section {
                Picker("Wheel of luck", selection: $moblinCloud.wheelOfLuckWidgetId) {
                    Text("None")
                        .tag(nil as UUID?)
                    ForEach(database.widgets.filter { $0.type == .wheelOfLuck }) {
                        Text($0.name)
                            .tag($0.id as UUID?)
                    }
                }
                .onChange(of: moblinCloud.wheelOfLuckWidgetId) { _ in
                    model.moblinCloudSendWheelOfLuck()
                }
            } footer: {
                Text("Wheel of luck widget viewers can spin.")
            }
        }
        .navigationTitle("Moblin cloud")
    }
}
