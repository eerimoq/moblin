import SwiftUI

private struct PermissionsSettingsView: View {
    // periphery:ignore
    @EnvironmentObject var model: Model
    var permissions: SettingsChatBotPermissionsCommand
    @State private var minimumSubscriberTier: Int

    init(permissions: SettingsChatBotPermissionsCommand) {
        self.permissions = permissions
        minimumSubscriberTier = permissions.minimumSubscriberTier!
    }

    var body: some View {
        Form {
            Section {
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
                Picker(selection: $minimumSubscriberTier) {
                    ForEach([3, 2, 1], id: \.self) { tier in
                        Text(String(tier))
                    }
                } label: {
                    Text("Minimum subscriber tier")
                }
                .onChange(of: minimumSubscriberTier) { value in
                    permissions.minimumSubscriberTier = value
                }
                Toggle(isOn: Binding(get: {
                    permissions.othersEnabled
                }, set: { value in
                    permissions.othersEnabled = value
                }), label: {
                    Text("Others")
                })
            } header: {
                Text("Permissions")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    permissions.sendChatMessages!
                }, set: { value in
                    permissions.sendChatMessages! = value
                }), label: {
                    Text("Send chat responses")
                })
            } footer: {
                Text("""
                Typically sends a chat message if the user is not allowed to execute the command. Some \
                commands responds on success as well.
                """)
            }
        }
        .navigationTitle("Command")
    }
}

struct ChatBotCommandsSettingsView: View {
    @EnvironmentObject var model: Model

    private var permissions: SettingsChatBotPermissions {
        model.database.chat.botCommandPermissions
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.fix)
                } label: {
                    Text("!moblin obs fix")
                }
            } footer: {
                Text("Fix OBS input.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.alert!)
                } label: {
                    Text("!moblin alert <name>")
                }
            } footer: {
                Text("Trigger alerts. Configure alert names in alert widgets.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.fax!)
                } label: {
                    Text("!moblin fax <url>")
                }
            } footer: {
                Text("Fax the streamer images.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.snapshot!)
                } label: {
                    Text("!moblin snapshot <optional message>")
                }
            } footer: {
                Text("Take snapshot.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.reaction!)
                } label: {
                    Text("!moblin reaction <reaction>")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Perform Apple reaction.")
                    Text("")
                    Text("<reaction> is hearts, fireworks, balloons, confetti or lasers.")
                }
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.filter!)
                } label: {
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
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.scene!)
                } label: {
                    Text("!moblin scene <name>")
                }
            } footer: {
                Text("Switch to given scene.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.stream!)
                } label: {
                    Text("!moblin stream ...")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("!moblin stream title <title>")
                    Text("Set stream title.")
                    Text("")
                    Text("!moblin stream category <category name>")
                    Text("Set stream category.")
                }
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.map)
                } label: {
                    Text("!moblin map zoom out")
                }
            } footer: {
                Text("Zoom out map widget temporarily.")
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.tts)
                } label: {
                    Text("!moblin tts/say ...")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("!moblin tts on")
                    Text("Turn on chat text to speech.")
                    Text("")
                    Text("!moblin tts off")
                    Text("Turn off chat text to speech.")
                    Text("")
                    Text("!moblin say <message>")
                    Text("Say given message.")
                }
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.audio!)
                } label: {
                    Text("!moblin mute/unmute")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("!moblin mute")
                    Text("Mute audio.")
                    Text("")
                    Text("!moblin unmute")
                    Text("Unmute audio.")
                }
            }
            Section {
                NavigationLink {
                    PermissionsSettingsView(permissions: permissions.tesla!)
                } label: {
                    Text("!moblin tesla ...")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("!moblin tesla trunk open")
                    Text("Open the trunk.")
                    Text("")
                    Text("!moblin tesla trunk close")
                    Text("Close the trunk.")
                    Text("")
                    Text("!moblin tesla media next")
                    Text("Next track.")
                    Text("")
                    Text("!moblin tesla media previous")
                    Text("Previous track.")
                    Text("")
                    Text("!moblin tesla media toggle-playback")
                    Text("Toggle playback.")
                }
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
                NavigationLink {
                    ChatBotCommandsSettingsView()
                } label: {
                    Text("Commands")
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.botSendLowBatteryWarning
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
