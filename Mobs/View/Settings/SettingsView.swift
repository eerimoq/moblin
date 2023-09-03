import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model

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
            NavigationLink(destination: ConnectionsSettingsView(model: model)) {
                Text("Connections")
            }
            NavigationLink(destination: ScenesSettingsView(model: model)) {
                Text("Scenes")
            }
            Section("Local overlays") {
                Toggle("Connection", isOn: Binding(get: {
                    database.show.connection
                }, set: { value in
                    database.show.connection = value
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
                Toggle("Resolution", isOn: Binding(get: {
                    database.show.resolution
                }, set: { value in
                    database.show.resolution = value
                    model.store()
                }))
                Toggle("FPS", isOn: Binding(get: {
                    database.show.fps
                }, set: { value in
                    database.show.fps = value
                    model.store()
                }))
            }
            Section("Help and support") {
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
        }
        .navigationTitle("Settings")
    }
}
