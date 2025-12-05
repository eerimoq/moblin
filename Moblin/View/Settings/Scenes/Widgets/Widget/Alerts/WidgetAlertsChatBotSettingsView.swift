import SwiftUI

private struct ChatBotCommandView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let command: SettingsWidgetAlertsChatBotCommand
    @State var name: String

    private func onSubmit(value: String) {
        command.name = value.lowercased().trim().replacingOccurrences(
            of: "\\s",
            with: "",
            options: .regularExpression
        )
        name = command.name
        model.updateAlertsSettings()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Toggle(isOn: Binding(get: {
                        alert.enabled
                    }, set: { value in
                        alert.enabled = value
                        model.updateAlertsSettings()
                    })) {
                        Text("Enabled")
                    }
                }
                Section {
                    TextEditNavigationView(title: String(localized: "Name"),
                                           value: name,
                                           onSubmit: onSubmit)
                } footer: {
                    Text("Trigger with chat message '!moblin alert \(name)'")
                }
                AlertMediaView(alert: alert)
                AlertPositionView(alert: alert, positionType: alert.positionType)
                AlertColorsView(
                    alert: alert,
                    textColor: alert.textColor.color(),
                    accentColor: alert.accentColor.color()
                )
                AlertFontView(
                    alert: alert,
                    fontSize: Float(alert.fontSize),
                    fontDesign: alert.fontDesign,
                    fontWeight: alert.fontWeight
                )
                AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay)
                Section {
                    TextButtonView("Test") {
                        model.testAlert(alert: .chatBotCommand(name, alertTestNames.randomElement()!))
                    }
                }
            }
            .navigationTitle("Command")
        } label: {
            Text(name.capitalized)
        }
    }
}

struct WidgetAlertsChatBotSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chatBot: SettingsWidgetAlertsChatBot

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chatBot.commands) { command in
                        ChatBotCommandView(
                            alert: command.alert,
                            command: command,
                            name: command.name
                        )
                    }
                    .onDelete { indexes in
                        chatBot.commands.remove(atOffsets: indexes)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let command = SettingsWidgetAlertsChatBotCommand()
                    chatBot.commands.append(command)
                    model.fixAlertMedias()
                    model.updateAlertsSettings()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Trigger alerts with chat bot commands.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a command"))
                }
            }
        }
        .navigationTitle("Chat bot")
    }
}
