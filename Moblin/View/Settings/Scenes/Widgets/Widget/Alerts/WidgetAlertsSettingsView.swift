import SwiftUI

private let testNames: [String] = ["Mark", "Natasha", "Pedro", "Anna"]

private struct TwitchFollowsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var textColor: Color
    @State var accentColor: Color
    @State var fontSize: Float

    var body: some View {
        Form {
            Toggle(isOn: Binding(get: {
                alert.enabled
            }, set: { value in
                alert.enabled = value
                model.updateAlertsSettings()
            })) {
                Text("Enabled")
            }
            Section {
                ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                    .onChange(of: textColor) { color in
                        guard let color = color.toRgb() else {
                            return
                        }
                        alert.textColor = color
                        model.updateAlertsSettings()
                    }
                ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { color in
                        guard let color = color.toRgb() else {
                            return
                        }
                        alert.accentColor = color
                        model.updateAlertsSettings()
                    }
            } header: {
                Text("Colors")
            }
            Section {
                HStack {
                    Text("Size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 80,
                        step: 5
                    )
                    .onChange(of: fontSize) { value in
                        alert.fontSize = Int(value)
                        model.updateAlertsSettings()
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 35)
                }
                HStack {
                    Text("Design")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontDesign.toString()
                    }, set: { value in
                        alert.fontDesign = SettingsFontDesign.fromString(value: value)
                        model.updateAlertsSettings()
                    })) {
                        ForEach(textWidgetFontDesigns, id: \.self) {
                            Text($0)
                        }
                    }
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontWeight.toString()
                    }, set: { value in
                        alert.fontWeight = SettingsFontWeight.fromString(value: value)
                        model.updateAlertsSettings()
                    })) {
                        ForEach(textWidgetFontWeights, id: \.self) {
                            Text($0)
                        }
                    }
                }
            } header: {
                Text("Font")
            }
            Section {
                Button(action: {
                    let event = TwitchEventSubNotificationChannelFollowEvent(
                        user_id: "",
                        user_login: "",
                        user_name: testNames.randomElement()!,
                        broadcaster_user_id: "",
                        broadcaster_user_login: "",
                        broadcaster_user_name: "",
                        followed_at: ""
                    )
                    model.testAlert(alert: .twitchFollow(event))
                }, label: {
                    HStack {
                        Spacer()
                        Text("Test")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("Follows")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct TwitchSubscriptionsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var textColor: Color
    @State var accentColor: Color
    @State var fontSize: Float

    var body: some View {
        Form {
            Toggle(isOn: Binding(get: {
                alert.enabled
            }, set: { value in
                alert.enabled = value
                model.updateAlertsSettings()
            })) {
                Text("Enabled")
            }
            Section {
                ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                    .onChange(of: textColor) { color in
                        guard let color = color.toRgb() else {
                            return
                        }
                        alert.textColor = color
                        model.updateAlertsSettings()
                    }
                ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { color in
                        guard let color = color.toRgb() else {
                            return
                        }
                        alert.accentColor = color
                        model.updateAlertsSettings()
                    }
            } header: {
                Text("Colors")
            }
            Section {
                HStack {
                    Text("Size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 80,
                        step: 5
                    )
                    .onChange(of: fontSize) { value in
                        alert.fontSize = Int(value)
                        model.updateAlertsSettings()
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 35)
                }
                HStack {
                    Text("Design")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontDesign.toString()
                    }, set: { value in
                        alert.fontDesign = SettingsFontDesign.fromString(value: value)
                        model.updateAlertsSettings()
                    })) {
                        ForEach(textWidgetFontDesigns, id: \.self) {
                            Text($0)
                        }
                    }
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontWeight.toString()
                    }, set: { value in
                        alert.fontWeight = SettingsFontWeight.fromString(value: value)
                        model.updateAlertsSettings()
                    })) {
                        ForEach(textWidgetFontWeights, id: \.self) {
                            Text($0)
                        }
                    }
                }
            } header: {
                Text("Font")
            }
            Section {
                Button(action: {
                    let event = TwitchEventSubNotificationChannelSubscribeEvent(
                        user_id: "",
                        user_login: "",
                        user_name: testNames.randomElement()!,
                        broadcaster_user_id: "",
                        broadcaster_user_login: "",
                        broadcaster_user_name: "",
                        tier: "",
                        is_gift: false
                    )
                    model.testAlert(alert: .twitchSubscribe(event))
                }, label: {
                    HStack {
                        Spacer()
                        Text("Test")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct WidgetAlertsSettingsTwitchView: View {
    var twitch: SettingsWidgetAlertsTwitch

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TwitchFollowsView(
                    alert: twitch.follows,
                    textColor: twitch.follows.textColor.color(),
                    accentColor: twitch.follows.accentColor.color(),
                    fontSize: Float(twitch.follows.fontSize)
                )) {
                    Text("Follows")
                }
                NavigationLink(destination: TwitchSubscriptionsView(
                    alert: twitch.subscriptions,
                    textColor: twitch.subscriptions.textColor.color(),
                    accentColor: twitch.subscriptions.accentColor.color(),
                    fontSize: Float(twitch.subscriptions.fontSize)
                )) {
                    Text("Subscriptions")
                }
            }
        }
        .navigationTitle("Twitch")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct WidgetAlertsSettingsView: View {
    var widget: SettingsWidget

    var body: some View {
        Section {
            Text("⚠️ Alerts does not yet work!")
        }
        Section {
            NavigationLink(destination: WidgetAlertsSettingsTwitchView(twitch: widget.alerts!.twitch!)) {
                Text("Twitch")
            }
        }
    }
}
