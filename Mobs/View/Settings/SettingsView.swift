import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    @State private var isPresentingResetConfirm: Bool = false


    var database: Database {
        get {
            model.settings.database
        }
    }

    func version() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    
    func openGithub() {
        UIApplication.shared.open(URL(string: "https://github.com/eerimoq/mobs")!)
    }
    
    func openDiscord() {
        UIApplication.shared.open(URL(string: "https://discord.gg/kRCXKuRu")!)
    }
    
    var body: some View {
        Form {
            Section("General") {
                NavigationLink(destination: StreamsSettingsView(model: model)) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView(model: model)) {
                    Text("Scenes")
                }
                NavigationLink(destination: ButtonsSettingsView(model: model)) {
                    Text("Buttons")
                }
            }
            Section {
                Toggle("Stream", isOn: Binding(get: {
                    database.show.stream
                }, set: { value in
                    database.show.stream  = value
                    model.store()
                }))
                Toggle("Viewers", isOn: Binding(get: {
                    database.show.viewers
                }, set: { value in
                    database.show.viewers = value
                    model.store()
                }))
                Toggle("Uptime", isOn: Binding(get: {
                    database.show.uptime
                }, set: { value in
                    database.show.uptime = value
                    model.store()
                }))
                Toggle("Chat", isOn: Binding(get: {
                    database.show.chat
                }, set: { value in
                    database.show.chat = value
                    model.store()
                }))
                Toggle("Speed", isOn: Binding(get: {
                    database.show.speed
                }, set: { value in
                    database.show.speed = value
                    model.store()
                }))
                Toggle("FPS", isOn: Binding(get: {
                    database.show.fps
                }, set: { value in
                    database.show.fps = value
                    model.store()
                }))
            } header: {
                Text("Local overlays")
            } footer: {
                Text("Local overlays do not appear on stream.")
            }
            Section("Help & support") {
                Button(action: {
                    openDiscord()
                }, label: {
                    Text("Discord")
                })
                Button(action: {
                    openGithub()
                }, label: {
                    Text("Github")
                })
            }
            Section("About") {
                TextItemView(name: "Version", value: version())
            }
            Section("Debug") {
                NavigationLink(destination: LogSettingsView(model: model)) {
                    Text("Log")
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Reset settings", role: .destructive) {
                        isPresentingResetConfirm = true
                    }
                    .confirmationDialog("Are you sure?", isPresented: $isPresentingResetConfirm) {
                        Button("Reset settings", role: .destructive) {
                            model.settings.reset()
                            model.reloadStream()
                            model.resetSelectedScene()
                         }
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
