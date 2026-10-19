import SwiftUI

private struct ChatBotCommandPrefixKey: EnvironmentKey {
    static let defaultValue = "!"
}

private extension EnvironmentValues {
    var chatBotCommandPrefix: String {
        get { self[ChatBotCommandPrefixKey.self] }
        set { self[ChatBotCommandPrefixKey.self] = newValue }
    }
}

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
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin obs fix"),
                permissions: permissions
            )
        } footer: {
            Text("Fix OBS input.")
        }
    }
}

private struct GimbalPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin gimbal preset <name>"),
                permissions: permissions
            )
        } footer: {
            Text("Move to given gimbal preset.")
        }
    }
}

private struct AlertPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin alert <name>"),
                permissions: permissions
            )
        } footer: {
            Text("Trigger alerts. Configure alert names in alert widgets.")
        }
    }
}

private struct FaxPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin fax <url>"),
                permissions: permissions
            )
        } footer: {
            Text("Fax the streamer images.")
        }
    }
}

private struct SnapshotPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand
    @ObservedObject var snapshot: SettingsChatBotCommandSnapshot

    var body: some View {
        Section {
            NavigationLink {
                Form {
                    Section {
                        Picker("Source", selection: $snapshot.source) {
                            ForEach(SettingsChatBotCommandSnapshotSource.allCases, id: \.self) { source in
                                Text(source.toString())
                            }
                        }
                        if snapshot.source == .webRemoteControl {
                            Picker("Use remote source", selection: $snapshot.webRemoteControlMode) {
                                ForEach(
                                    SettingsChatBotCommandSnapshotWebRemoteControlMode.allCases,
                                    id: \.self
                                ) {
                                    Text($0.toString())
                                }
                            }
                            TextEditNavigationView(
                                title: String(localized: "URL"),
                                value: snapshot.webRemoteControlUrl,
                                onChange: isValidHttpUrl,
                                onSubmit: { snapshot.webRemoteControlUrl = cleanUrl(url: $0) },
                                placeholder: "http://192.168.1.10:\(DefaultTcpPorts.remoteControlWeb)"
                            )
                        }
                    } footer: {
                        Text("""
                        Take the snapshot on this device, or fetch it from another device's web remote \
                        control.
                        """)
                    }
                    PermissionsSettingsInnerView(permissions: permissions)
                }
                .navigationTitle(String(localized: "\(commandPrefix)moblin snapshot <optional message>"))
            } label: {
                Text("\(commandPrefix)moblin snapshot <optional message>")
            }
        } footer: {
            Text("Take snapshot.")
        }
    }
}

private struct ReactionPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin reaction <reaction>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("Perform reaction.")
                Text("")
                Text("<reaction> is hearts, fireworks, balloons, confetti, lasers, glasses or sparkle.")
            }
        }
    }
}

private struct FilterPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin filter <filter> <on/off>"),
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

private struct ZoomPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin zoom <x>"),
                permissions: permissions
            )
        } footer: {
            Text("Set zoom for the current camera.")
        }
    }
}

private struct ScenePermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin scene <name>"),
                permissions: permissions
            )
        } footer: {
            Text("Switch to given scene.")
        }
    }
}

private struct StreamPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin stream ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin stream start")
                Text("Start the stream.")
                Text("")
                Text("\(commandPrefix)moblin stream stop")
                Text("Stop the stream.")
                Text("")
                Text("\(commandPrefix)moblin stream title <title>")
                Text("Set stream title.")
                Text("")
                Text("\(commandPrefix)moblin stream category <category name>")
                Text("Set stream category.")
            }
        }
    }
}

private struct WidgetPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin widget ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin widget <name> enable")
                Text("Enable given widget.")
                Text("")
                Text("\(commandPrefix)moblin widget <name> disable")
                Text("Disable given widget.")
                Text("")
                Text("\(commandPrefix)moblin widget <name> wheelofluck options <option 1> <option 2> ...")
                Text("Set options for given wheel of luck.")
                Text("")
                Text("\(commandPrefix)moblin widget <name> wheelofluck spin")
                Text("Spin given wheel of luck.")
                Text("")
                Text("\(commandPrefix)moblin widget <name> timer <number> add <seconds>")
                Text("Change timer value.")
            }
        }
    }
}

private struct LocationPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin location ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin location data reset")
                Text("Resets distances, average speed and slope.")
                Text("")
                Text("\(commandPrefix)moblin location data split")
                Text("Reset split distance.")
            }
        }
    }
}

private struct MapPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin map zoom out"),
                permissions: permissions
            )
        } footer: {
            Text("Zoom out map widget temporarily.")
        }
    }
}

private struct TtsSayPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin tts/say ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin tts on")
                Text("Turn on chat text to speech.")
                Text("")
                Text("\(commandPrefix)moblin tts off")
                Text("Turn off chat text to speech.")
                Text("")
                Text("\(commandPrefix)moblin say <message>")
                Text("Say given message.")
            }
        }
    }
}

private struct AiPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    @ObservedObject var permissions: SettingsChatBotPermissionsCommand
    let ai: SettingsOpenAi

    var body: some View {
        Section {
            NavigationLink {
                Form {
                    OpenAiSettingsView(ai: ai)
                    PermissionsSettingsInnerView(permissions: permissions)
                }
                .navigationTitle(String(localized: "\(commandPrefix)moblin ai ask <question>"))
            } label: {
                Text("\(commandPrefix)moblin ai ask <question>")
            }
        } footer: {
            Text("Ask an AI a question.")
        }
    }
}

private struct TwitchPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    @ObservedObject var permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin twitch ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin twitch raid <channel>")
                Text("Raid given channel.")
            }
        }
    }
}

private struct MuteUnmutePermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin mute/unmute"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin mute")
                Text("Mute audio.")
                Text("")
                Text("\(commandPrefix)moblin unmute")
                Text("Unmute audio.")
            }
        }
    }
}

private struct TorchPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin torch ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin torch on")
                Text("Turn the torch on.")
                Text("")
                Text("\(commandPrefix)moblin torch off")
                Text("Turn the torch off.")
                Text("")
                Text("\(commandPrefix)moblin torch level <level>")
                Text("Set torch level, from 1 to 100.")
            }
        }
    }
}

private struct VibratePermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin vibrate ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin vibrate on [<seconds>] [<intensity>] [<sharpness>]")
                Text("Vibrate the phone. Until turned off if no seconds is given.")
                Text("Intensity and sharpness from 1 to 100, default 100 and 50.")
                Text("")
                Text("\(commandPrefix)moblin vibrate off")
                Text("Stop vibrating the phone.")
            }
        }
    }
}

private struct TeslaPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin tesla ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin tesla trunk open")
                Text("Open the trunk.")
                Text("")
                Text("\(commandPrefix)moblin tesla trunk close")
                Text("Close the trunk.")
                Text("")
                Text("\(commandPrefix)moblin tesla media next")
                Text("Next track.")
                Text("")
                Text("\(commandPrefix)moblin tesla media previous")
                Text("Previous track.")
                Text("")
                Text("\(commandPrefix)moblin tesla media toggle-playback")
                Text("Toggle playback.")
            }
        }
    }
}

private struct MacroPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin macro <run/cancel> <name>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin macro run <name>")
                Text("Run given macro.")
                Text("")
                Text("\(commandPrefix)moblin macro cancel <name>")
                Text("Cancel given macro.")
            }
        }
    }
}

private struct SendPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin send <message>"),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin send <message>")
                Text("Send given message.")
            }
        }
    }
}

private struct AppleMusicPermissionsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let permissions: SettingsChatBotPermissionsCommand

    var body: some View {
        Section {
            PermissionsSettingsView(
                title: String(localized: "\(commandPrefix)moblin music ..."),
                permissions: permissions
            )
        } footer: {
            VStack(alignment: .leading) {
                Text("\(commandPrefix)moblin music add <song>")
                Text("Add given song to the queue.")
                Text("<song> is either a share link or text search.")
                Text("")
                Text("\(commandPrefix)moblin music play")
                Text("Play.")
                Text("")
                Text("\(commandPrefix)moblin music pause")
                Text("Pause.")
                Text("")
                Text("\(commandPrefix)moblin music next")
                Text("Next song.")
                Text("")
                Text("\(commandPrefix)moblin music previous")
                Text("Previous song.")
                Text("")
                Text("\(commandPrefix)moblin music status")
                Text("Show status.")
                Text("")
                Text("\(commandPrefix)moblin music clear")
                Text("Clear the queue.")
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
            GimbalPermissionsSettingsView(permissions: permissions.gimbal)
            LocationPermissionsSettingsView(permissions: permissions.location)
            MacroPermissionsSettingsView(permissions: permissions.macro)
            MapPermissionsSettingsView(permissions: permissions.map)
            MuteUnmutePermissionsSettingsView(permissions: permissions.audio)
            ReactionPermissionsSettingsView(permissions: permissions.reaction)
            ScenePermissionsSettingsView(permissions: permissions.scene)
            SnapshotPermissionsSettingsView(permissions: permissions.snapshot,
                                            snapshot: model.database.chat.botCommandSnapshot)
            StreamPermissionsSettingsView(permissions: permissions.stream)
            TeslaPermissionsSettingsView(permissions: permissions.tesla)
            TorchPermissionsSettingsView(permissions: permissions.torch)
            VibratePermissionsSettingsView(permissions: permissions.vibrate)
            SendPermissionsSettingsView(permissions: permissions.send)
            AppleMusicPermissionsSettingsView(permissions: permissions.music)
            TtsSayPermissionsSettingsView(permissions: permissions.tts)
            WidgetPermissionsSettingsView(permissions: permissions.widget)
            TwitchPermissionsSettingsView(permissions: permissions.twitch)
            ZoomPermissionsSettingsView(permissions: permissions.zoom)
        }
        .navigationTitle("Commands")
    }
}

private struct ChatBotAliasSettingsView: View {
    @ObservedObject var alias: SettingsChatBotAlias
    @ObservedObject var chat: SettingsChat

    private var editableAlias: String {
        guard let canonical = ChatBotPrefix.canonicalAlias(alias.alias) else {
            return alias.alias
        }
        return chat.effectiveBotCommandPrefixes[0] + canonical.dropFirst()
    }

    private var displayReplacement: String {
        let canonical = ChatBotPrefix.canonicalReplacement(alias.replacement)
        guard let replacement = canonical ?? (alias.replacement == "!moblin" ? alias.replacement : nil) else {
            return alias.replacement
        }
        return chat.effectiveBotCommandPrefixes[0] + replacement.dropFirst()
    }

    private var displayAlias: String {
        guard let canonical = ChatBotPrefix.canonicalAlias(alias.alias) else {
            return alias.alias
        }
        return chat.effectiveBotCommandPrefixes.map { $0 + canonical.dropFirst() }.joined(separator: ", ")
    }

    private func onAliasChange(value: String) -> String? {
        guard let canonical = ChatBotPrefix.canonicalAlias(value) else {
            return String(
                localized: "Use !, . or / followed by one alias name that does not start with moblin."
            )
        }
        guard !chat.aliases.contains(where: {
            $0.id != alias.id && ChatBotPrefix.canonicalAlias($0.alias) == canonical
        }) else {
            return String(localized: "An alias with this name already exists.")
        }
        return nil
    }

    private func onReplacementChange(value: String) -> String? {
        guard ChatBotPrefix.canonicalReplacement(value) != nil else {
            return String(localized: "Use !moblin, .moblin or /moblin followed by a command.")
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
                            value: editableAlias,
                            onChange: onAliasChange
                        ) {
                            alias.alias = ChatBotPrefix.canonicalAlias($0) ?? alias.alias
                        }
                    } label: {
                        TextItemLocalizedView(name: "Alias", value: displayAlias)
                    }
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Replacement"),
                            value: displayReplacement,
                            onChange: onReplacementChange
                        ) {
                            alias.replacement = ChatBotPrefix.canonicalReplacement($0) ?? alias.replacement
                        }
                    } label: {
                        TextItemLocalizedView(
                            name: "Replacement",
                            value: displayReplacement
                        )
                    }
                } footer: {
                    Text("Aliases work with every enabled prefix.")
                }
            }
            .navigationTitle("Alias")
        } label: {
            HStack {
                Text(displayAlias)
                Spacer()
                GrayTextView(text: displayReplacement)
            }
        }
    }
}

private struct ChatBotCustomCommandTextSettingsView: View {
    @EnvironmentObject var model: Model
    let customCommand: SettingsChatBotCustomCommand
    @State var value: String

    var body: some View {
        Form {
            TextWidgetTextView(value: $value)
            TextFormatWarningsView(model: model, location: model.database.location, value: $value)
            Section {
                TextWidgetSuggestionsView(widget: false, text: $value)
            }
            TextFormatVariablesView(model: model, widget: false, value: $value)
        }
        .onChange(of: value) { _ in
            customCommand.formatString = value
            model.chatBotCustomCommandsTextChanged()
        }
        .navigationTitle("Text")
    }
}

private struct ChatBotCustomCommandSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    @ObservedObject var customCommand: SettingsChatBotCustomCommand

    private func onNameChange(value: String) -> String? {
        guard !value.isEmpty else {
            return String(localized: "The name must not be empty.")
        }
        return nil
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Name"),
                            value: customCommand.name,
                            onChange: onNameChange
                        ) {
                            customCommand.name = $0
                        }
                    } label: {
                        TextItemLocalizedView(name: "Name", value: customCommand.name)
                    }
                    NavigationLink {
                        ChatBotCustomCommandTextSettingsView(
                            customCommand: customCommand,
                            value: customCommand.formatString
                        )
                    } label: {
                        TextItemLocalizedView(name: "Text", value: customCommand.formatString)
                    }
                } footer: {
                    Text("Send the text to chat when a user sends \(commandPrefix)moblin custom <name>.")
                }
                PermissionsSettingsInnerView(permissions: customCommand.permissions)
            }
            .navigationTitle("Command")
        } label: {
            HStack {
                Text(customCommand.name)
                Spacer()
                GrayTextView(text: customCommand.formatString)
            }
        }
    }
}

private struct ChatBotCustomCommandsSettingsView: View {
    @Environment(\.chatBotCommandPrefix) private var commandPrefix
    let model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chat.customCommands) { customCommand in
                        ChatBotCustomCommandSettingsView(customCommand: customCommand)
                            .contextMenuDeleteButton {
                                chat.customCommands.removeAll { $0.id == customCommand.id }
                                model.chatBotCustomCommandsTextChanged()
                            }
                    }
                    .onMove { froms, to in
                        chat.customCommands.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        chat.customCommands.remove(atOffsets: offsets)
                        model.chatBotCustomCommandsTextChanged()
                    }
                }
                CreateButtonView {
                    chat.customCommands.append(SettingsChatBotCustomCommand())
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("\(commandPrefix)moblin custom <name>")
                    Text("Send the text of the command with given name to chat.")
                }
            }
        }
        .navigationTitle("Custom commands")
    }
}

private struct ChatBotAliasesSettingsView: View {
    @ObservedObject var chat: SettingsChat

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chat.aliases) { alias in
                        ChatBotAliasSettingsView(alias: alias, chat: chat)
                            .contextMenuDeleteButton {
                                chat.aliases.removeAll { $0.id == alias.id }
                            }
                    }
                    .onMove { froms, to in
                        chat.aliases.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        chat.aliases.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let alias = SettingsChatBotAlias()
                    var number = 2
                    while chat.aliases.contains(where: {
                        ChatBotPrefix.canonicalAlias($0.alias) == alias.alias
                    }) {
                        alias.alias = "!myalias\(number)"
                        number += 1
                    }
                    chat.aliases.append(alias)
                }
            }
        }
        .navigationTitle("Aliases")
    }
}

private struct ChatBotSettingsInnerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
        Form {
            Section {
                ForEach(ChatBotPrefix.supported, id: \.self) { prefix in
                    Toggle(isOn: Binding(get: {
                        chat.effectiveBotCommandPrefixes.contains(prefix)
                    }, set: { enabled in
                        var prefixes = chat.effectiveBotCommandPrefixes
                        if enabled {
                            prefixes.append(prefix)
                        } else {
                            prefixes.removeAll { $0 == prefix }
                        }
                        chat.botCommandPrefixes = ChatBotPrefix.normalized(prefixes)
                    })) {
                        Text(verbatim: prefix)
                    }
                    .disabled(chat.effectiveBotCommandPrefixes == [prefix])
                }
            } header: {
                Text("Command prefixes")
            } footer: {
                Text("Commands and aliases work with every enabled prefix. Keep at least one enabled.")
            }
            Section {
                NavigationLink {
                    ChatBotCommandsSettingsView()
                } label: {
                    Text("Commands")
                }
                NavigationLink {
                    ChatBotCustomCommandsSettingsView(model: model, chat: model.database.chat)
                } label: {
                    Text("Custom commands")
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
        .environment(\.chatBotCommandPrefix, chat.effectiveBotCommandPrefixes[0])
        .onChange(of: chat.botCommandPrefixes) { _ in
            model.chatTextToSpeech.setCommandPrefixes(prefixes: chat.effectiveBotCommandPrefixes)
        }
    }
}

struct ChatBotSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ChatBotSettingsInnerView(chat: model.database.chat)
    }
}
