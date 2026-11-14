import SwiftUI

struct MoblinCloudSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var moblinCloud: SettingsMoblinCloud

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image("MoblinCloudLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 110)
                    Text("Moblin Cloud")
                        .font(.title2)
                        .bold()
                    Text("Let viewers interact with your stream from your own page.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                Label {
                    Text("Sign in at [cloud.moblin.app](https://cloud.moblin.app) and set up your page.")
                } icon: {
                    Image(systemName: "1.circle.fill")
                }
                Label {
                    Text(
                        "Scan the QR code in the dashboard's Moblin section, or paste your Moblin Cloud key below."
                    )
                } icon: {
                    Image(systemName: "2.circle.fill")
                }
                Label {
                    Text(
                        "Pick the alerts widget that shows messages and the wheel of luck widget that viewers spin."
                    )
                } icon: {
                    Image(systemName: "3.circle.fill")
                }
            } header: {
                Text("Get started")
            }
            Section {
                Link(destination: URL(string: "https://moblin.app/docs/#guides/moblin-cloud")!) {
                    Label("Read the guide", systemImage: "book")
                }
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
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: moblinCloud.url,
                    onChange: isValidHttpUrl,
                    onSubmit: {
                        moblinCloud.url = $0
                        model.reloadMoblinCloud()
                    }
                )
            } footer: {
                Text("Moblin Cloud API server. Default is \(moblinCloudApiUrl).")
            }
        }
        .navigationTitle("Moblin Cloud")
    }
}
