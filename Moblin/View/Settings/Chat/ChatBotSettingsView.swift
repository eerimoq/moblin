import SwiftUI

private struct PermissionsSettingsInnerView: View {
    @ObservedObject var permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            Toggle("Moderators", isOn: $permissions.moderatorsEnabled)
            Toggle("Subscribers", isOn: $permissions.subscribersEnabled)
            Picker("Minimum subscriber tier", selection: $permissions.minimumSubscriberTier) {
                ForEach([3, 2, 1], id: \.self) { tier in
                    Text(String(tier))
                }
            }
            Toggle("Others", isOn: $permissions.othersEnabled)
        } header: {
            Text("Permissions")
        }
        Section {
            Picker("Cooldown", selection: $permissions.cooldown) {
                Text("-- None --")
                    .tag(nil as Int?)
                ForEach([1, 2, 3, 5, 10, 15, 30, 60], id: \.self) { cooldown in
                    Text("\(cooldown)s")
                        .tag(cooldown as Int?)
                }
            }
        } footer: {
            Text("Does not apply to you and your moderators.")
        }
        Section {
            Toggle("Send chat responses", isOn: $permissions.sendChatMessages)
        } footer: {
            Text("""
            Typically sends a chat message if the user is not allowed to execute the command. Some \
            commands responds on success as well.
            """)
        }
    }
}

private struct PermissionsSettingsView: View {
    let title: String
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        NavigationLink {
            Form {
                PermissionsSettingsInnerView(permissions: permissions)
            }
            .navigationTitle(title)
        } label: {
            Text(title)
        }
    }
}

private struct FixPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin obs fix",
                permissions: permissions
            )
        } footer: {
            Text("Fix OBS input.")
        }
    }
}

private struct AlertPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin alert <name>"),
                permissions: permissions
            )
        } footer: {
            Text("Trigger alerts. Configure alert names in alert widgets.")
        }
    }
}

private struct FaxPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin fax <url>"),
                permissions: permissions
            )
        } footer: {
            Text("Fax the streamer images.")
        }
    }
}

private struct SnapshotPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin snapshot <optional message>"),
                permissions: permissions
            )
        } footer: {
            Text("Take snapshot.")
        }
    }
}

private struct ReactionPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin reaction <reaction>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("Perform Apple reaction.")
                Text("")
                Text("<reaction> is hearts, fireworks, balloons, confetti or lasers.")
            }
        }
    }
}

private struct FilterPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin filter <filter> <on/off>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("Turn a filter on or off.")
                Text("")
                Text("<filter> is movie, grayscale, sepia, triple, pixellate or 4:3.")
                Text("")
                Text("<on/off> is on or off.")
            }
        }
    }
}

private struct ScenePermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin scene <name>"),
                permissions: permissions
            )
        } footer: {
            Text("Switch to given scene.")
        }
    }
}

private struct StreamPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin stream ...",
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text(String("!moblin stream start"))
                Text("Start the stream.")
                Text("")
                Text(String("!moblin stream stop"))
                Text("Stop the stream.")
                Text("")
                Text("!moblin stream title <title>")
                Text("Set stream title.")
                Text("")
                Text("!moblin stream category <category name>")
                Text("Set stream category.")
            }
        }
    }
}

private struct WidgetPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "!moblin widget <name> timer <number> add <seconds>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("!moblin widget <name> timer <number> add <seconds>")
                Text("Change timer value.")
            }
        }
    }
}

private struct LocationPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "moblin location data reset",
                permissions: permissions
            )
        } footer: {
            Text("Resets distance, average speed and slope.")
        }
    }
}

private struct MapPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "moblin map zoom out",
                permissions: permissions
            )
        } footer: {
            Text("Zoom out map widget temporarily.")
        }
    }
}

private struct TtsSayPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin tts/say ...",
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text(String("!moblin tts on"))
                Text("Turn on chat text to speech.")
                Text("")
                Text(String("!moblin tts off"))
                Text("Turn off chat text to speech.")
                Text("")
                Text("!moblin say <message>")
                Text("Say given message.")
            }
        }
    }
}

private struct AiPermissionsSettingsView: View {
    @ObservedObject var permissions: SettingsChatBotPermissionsCommand
    let ai: SettingsOpenAi

    var body: some View {
        Section {
            NavigationLink {
                Form {
                    OpenAiSettingsView(ai: ai)
                    PermissionsSettingsInnerView(permissions: permissions)
                }
                .navigationTitle("!moblin ai ask <question>")
            } label: {
                Text("!moblin ai ask <question>")
            }
        } footer: {
            Text("Ask an AI a question.")
        }
    }
}

private struct TwitchPermissionsSettingsView: View {
    @ObservedObject var permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin twitch ...",
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text(String("!moblin twitch raid <channel>"))
                Text("Raid given channel.")
            }
        }
    }
}

private struct MuteUnmutePermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin mute/unmute",
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text(String("!moblin mute"))
                Text("Mute audio.")
                Text("")
                Text(String("!moblin unmute"))
                Text("Unmute audio.")
            }
        }
    }
}

private struct TeslaPermissionsSettingsView: View {
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: "!moblin tesla ...",
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text(String("!moblin tesla trunk open"))
                Text("Open the trunk.")
                Text("")
                Text(String("!moblin tesla trunk close"))
                Text("Close the trunk.")
                Text("")
                Text(String("!moblin tesla media next"))
                Text("Next track.")
                Text("")
                Text(String("!moblin tesla media previous"))
                Text("Previous track.")
                Text("")
                Text(String("!moblin tesla media toggle-playback"))
                Text("Toggle playback.")
            }
        }
    }
}

private struct ChatBotCommandsSettingsView: View {
    @EnvironmentObject var model: Model

    private var permissions: SettingsChatBotPermissions {
        model.database.chat.botCommandPermissions
    }

    var body: some View {
        Form {
            AiPermissionsSettingsView(permissions: permissions.ai, ai: model.database.chat.botCommandAi)
            AlertPermissionsSettingsView(permissions: permissions.alert)
            FaxPermissionsSettingsView(permissions: permissions.fax)
            FilterPermissionsSettingsView(permissions: permissions.filter)
            FixPermissionsSettingsView(permissions: permissions.fix)
            LocationPermissionsSettingsView(permissions: permissions.location)
            MapPermissionsSettingsView(permissions: permissions.map)
            MuteUnmutePermissionsSettingsView(permissions: permissions.audio)
            ReactionPermissionsSettingsView(permissions: permissions.reaction)
            ScenePermissionsSettingsView(permissions: permissions.scene)
            SnapshotPermissionsSettingsView(permissions: permissions.snapshot)
            StreamPermissionsSettingsView(permissions: permissions.stream)
            TeslaPermissionsSettingsView(permissions: permissions.tesla)
            TtsSayPermissionsSettingsView(permissions: permissions.tts)
            WidgetPermissionsSettingsView(permissions: permissions.widget)
            TwitchPermissionsSettingsView(permissions: permissions.twitch)
        }
        .navigationTitle("Commands")
    }
}

private struct ChatBotAliasSettingsView: View {
    @ObservedObject var alias: SettingsChatBotAlias

    private func onAliasChange(value: String) -> String? {
        guard !value.isEmpty else {
            return String(localized: "The alias must not be empty.")
        }
        guard value.starts(with: "!") else {
            return String(localized: "The alias must start with !.")
        }
        guard value.count > 1 else {
            return String(localized: "The alias is too short.")
        }
        guard !value.starts(with: "!moblin") else {
            return String(localized: "The alias must not start with !moblin.")
        }
        guard value.split(separator: " ").count == 1 else {
            return String(localized: "The alias must be exactly one word.")
        }
        return nil
    }

    private func onReplacementChange(value: String) -> String? {
        guard !value.isEmpty else {
            return String(localized: "The replacement must not be empty.")
        }
        guard value.starts(with: "!moblin") else {
            return String(localized: "The replacement must start with !moblin.")
        }
        guard value.split(separator: " ").count > 1 else {
            return String(localized: "The replacement must be more than one word.")
        }
        return nil
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Alias"),
                            value: alias.alias,
                            onChange: onAliasChange
                        ) {
                            alias.alias = $0
                        }
                    } label: {
                        TextItemLocalizedView(name: "Alias", value: alias.alias)
                    }
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Replacement"),
                            value: alias.replacement,
                            onChange: onReplacementChange
                        ) {
                            alias.replacement = $0
                        }
                    } label: {
                        TextItemLocalizedView(name: "Replacement", value: alias.replacement)
                    }
                }
            }
            .navigationTitle("Alias")
        } label: {
            HStack {
                Text(alias.alias)
                Spacer()
                GrayTextView(text: alias.replacement)
            }
        }
    }
}

private struct ChatBotAliasesSettingsView: View {
    @ObservedObject var chat: SettingsChat

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chat.aliases) { alias in
                        ChatBotAliasSettingsView(alias: alias)
                    }
                    .onMove { froms, to in
                        chat.aliases.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        chat.aliases.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    chat.aliases.append(SettingsChatBotAlias())
                }
            }
        }
        .navigationTitle("Aliases")
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
                NavigationLink {
                    ChatBotAliasesSettingsView(chat: model.database.chat)
                } label: {
                    Text("Aliases")
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
