import SwiftUI

private struct StartSongRequestsView: View {
    let model: Model
    @Binding var presenting: Bool
    @State var hours: Int?

    var body: some View {
        VStack {
            VStack {
                Text("Time limit")
                Picker("", selection: $hours) {
                    Text("Unlimited")
                        .tag(nil as Int?)
                    ForEach(1 ... 24, id: \.self) {
                        Text(formatShortDuration(seconds: $0 * 3600))
                            .tag($0 as Int?)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 200, height: 150)
                if let hours {
                    Text("Last song ends \(Date() + Double(hours * 3600), style: .time)")
                } else {
                    Text("No time limit")
                }
            }
            .padding()
            HStack {
                TimeButtonView(text: "OK") {
                    model.startMoblinCloudSongRequests(hours: hours)
                    presenting = false
                }
                TimeButtonView(text: "Cancel") {
                    presenting = false
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }
}

struct MoblinCloudSongRequestsView: View {
    let model: Model
    @ObservedObject var moblinCloud: SettingsMoblinCloud
    @State private var presentingStart = false

    var body: some View {
        Toggle("Song requests", isOn: Binding(get: {
            moblinCloud.songRequests
        }, set: {
            if $0 {
                presentingStart = true
            } else {
                model.stopMoblinCloudSongRequests()
            }
        }))
        .popover(isPresented: $presentingStart) {
            StartSongRequestsView(model: model,
                                  presenting: $presentingStart,
                                  hours: moblinCloud.songRequestsHours)
        }
        if moblinCloud.songRequests, moblinCloud.songRequestsHours != nil {
            Text("Last song ends \(moblinCloud.songRequestsEndTime, style: .time)")
        }
    }
}

struct MoblinCloudSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var moblinCloud: SettingsMoblinCloud

    var body: some View {
        Form {
            Section {
                Text("""
                Let viewers interact with your stream from your page at https://moblin.app. \
                Sign in at https://moblin.app/dashboard to get your Moblin Cloud key.
                """)
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
                Picker("Tips", selection: $moblinCloud.alertsWidgetId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(database.widgets.filter { $0.type == .alerts }) {
                        Text($0.name)
                            .tag($0.id as UUID?)
                    }
                }
            } footer: {
                Text("Alerts widget that shows tips.")
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
                Text("Wheel of luck widget viewers can spin.")
            }
            Section {
                MoblinCloudSongRequestsView(model: model, moblinCloud: moblinCloud)
            } footer: {
                Text("""
                Let viewers add songs to your Apple Music queue. The queue is still shown when disabled.
                """)
            }
        }
        .navigationTitle("Moblin Cloud")
    }
}
