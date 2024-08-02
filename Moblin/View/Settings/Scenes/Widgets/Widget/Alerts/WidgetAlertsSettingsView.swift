import SwiftUI

private struct TwitchFollowsView: View {
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var textColor: Color
    @State var accentColor: Color
    @State var fontSize: Float

    var body: some View {
        Form {
            Section {
                Text("Image")
            }
            Section {
                Text("Sound")
            }
            Section {
                ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                    .onChange(of: textColor) { _ in
                    }
                ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { _ in
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
                        step: 5,
                        onEditingChanged: { _ in
                        }
                    )
                    Text(String(Int(fontSize)))
                        .frame(width: 35)
                }
                HStack {
                    Text("Design")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontDesign.toString()
                    }, set: { _ in
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
                    }, set: { _ in
                    })) {
                        ForEach(textWidgetFontWeights, id: \.self) {
                            Text($0)
                        }
                    }
                }
            } header: {
                Text("Font")
            }
        }
        .navigationTitle("Follows")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct TwitchSubscriptionsView: View {
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var textColor: Color
    @State var accentColor: Color
    @State var fontSize: Float

    var body: some View {
        Form {
            Section {
                Text("Image")
            }
            Section {
                Text("Sound")
            }
            Section {
                ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                    .onChange(of: textColor) { _ in
                    }
                ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { _ in
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
                        step: 5,
                        onEditingChanged: { _ in
                        }
                    )
                    Text(String(Int(fontSize)))
                        .frame(width: 35)
                }
                HStack {
                    Text("Design")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        alert.fontDesign.toString()
                    }, set: { _ in
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
                    }, set: { _ in
                    })) {
                        ForEach(textWidgetFontWeights, id: \.self) {
                            Text($0)
                        }
                    }
                }
            } header: {
                Text("Font")
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
            NavigationLink(destination: WidgetAlertsSettingsTwitchView(twitch: widget.alerts!.twitch!)) {
                Text("Twitch")
            }
        }
    }
}
