import SwiftUI

private struct PermissionsSettingsView: View {
    // periphery:ignore
    @EnvironmentObject var model: Model
    var permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Form {
            Toggle(isOn: Binding(get: {
                permissions.moderatorsEnabled
            }, set: { value in
                permissions.moderatorsEnabled = value
            }), label: {
                Text("Moderators")
            })
            Toggle(isOn: Binding(get: {
                permissions.subscribersEnabled!
            }, set: { value in
                permissions.subscribersEnabled = value
            }), label: {
                Text("Subscribers")
            })
            Toggle(isOn: Binding(get: {
                permissions.othersEnabled
            }, set: { value in
                permissions.othersEnabled = value
            }), label: {
                Text("Others")
            })
        }
        .navigationTitle("Permissions")
    }
}

struct ChatBotCommandsSettingsView: View {
    @EnvironmentObject var model: Model

    private var permissions: SettingsChatBotPermissions {
        model.database.chat.botCommandPermissions!
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.fix)) {
                    Text("!moblin obs fix")
                }
            } footer: {
                Text("Fix OBS input.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.alert!)) {
                    Text("!moblin alert <name>")
                }
            } footer: {
                Text("Trigger alerts. Configure alert names in alert widgets.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.fax!)) {
                    Text("!moblin fax <url>")
                }
            } footer: {
                Text("Fax the streamer images.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.snapshot!)) {
                    Text("!moblin snapshot")
                }
            } footer: {
                Text("Take snapshot.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.filter!)) {
                    Text("!moblin filter <filter> <on/off>")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Turn a filter on or off.")
                    Text("")
                    Text("<filter> is movie, grayscale, sepia, triple, pixellate or 4:3.")
                    Text("")
                    Text("<on/off> is on or off.")
                }
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.map)) {
                    Text("!moblin map zoom out")
                }
            } footer: {
                Text("Zoom out map widget temporarily.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.tts)) {
                    Text("!moblin tts on")
                }
            } footer: {
                Text("Turn on chat text to speech.")
            }
            Section {
                NavigationLink(destination: PermissionsSettingsView(permissions: permissions.tts)) {
                    Text("!moblin tts off")
                }
            } footer: {
                Text("Turn off chat text to speech.")
            }
        }
        .navigationTitle("Commands")
    }
}

struct ChatBotSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: ChatBotCommandsSettingsView()) {
                    Text("Commands")
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.botSendLowBatteryWarning!
                }, set: { value in
                    model.database.chat.botSendLowBatteryWarning = value
                }), label: {
                    Text("Send low battery message")
                })
            }
        }
        .navigationTitle("Bot")
    }
}
