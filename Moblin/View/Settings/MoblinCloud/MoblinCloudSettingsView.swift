import SwiftUI

struct MoblinCloudSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var moblinCloud: SettingsMoblinCloud

    var body: some View {
        Form {
            Section {
                Text("Let viewers interact with your stream from your page at https://moblin.app")
                Text("""
                1. Sign in at https://moblin.app/dashboard and set up your page.
                2. Scan the QR code in the dashboard's Moblin section, or paste your Moblin Cloud key below.
                3. Pick the alerts widget that shows messages and the wheel of luck widget that viewers spin.
                """)
                Text("Guide: https://moblin.app/docs/#guides/moblin-cloud")
            }
            Section {
                Toggle("Enabled", isOn: $moblinCloud.enabled)
                    .onChange(of: moblinCloud.enabled) { _ in
                        model.reloadMoblinCloud()
                    }
                TextEditNavigationView(
                    title: String(localized: "Moblin Cloud key"),
                    value: moblinCloud.key,
                    onSubmit: {
                        moblinCloud.key = $0
                        model.reloadMoblinCloud()
                    },
                    sensitive: true
                )
            } footer: {
                Text("Keep the Moblin Cloud key to yourself.")
            }
            Section {
                Picker("Message", selection: $moblinCloud.alertsWidgetId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(database.widgets.filter { $0.type == .alerts }) {
                        Text($0.name)
                            .tag($0.id as UUID?)
                    }
                }
            } footer: {
                Text("""
                Alerts widget that shows messages on stream. Messages always show in chat. \
                Create one in Settings → Scenes and add it to the scenes you stream with.
                """)
            }
            Section {
                Picker("Wheel of luck", selection: $moblinCloud.wheelOfLuckWidgetId) {
                    Text("-- None --")
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
                Text("""
                Wheel of luck widget that viewers spin. Viewers can only spin while one is picked. \
                Create one in Settings → Scenes and add it to the scenes you stream with.
                """)
            }
        }
        .navigationTitle("Moblin Cloud")
    }
}
