import SwiftUI
import UniformTypeIdentifiers

private let testNames: [String] = ["Mark", "Natasha", "Pedro", "Anna"]

private struct AlertPickerView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model
    let type: UTType

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [type],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

private struct AlertFontView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var fontSize: Float

    var body: some View {
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
    }
}

private struct AlertColorsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var textColor: Color
    @State var accentColor: Color

    var body: some View {
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
    }
}

private struct AlertTextToSpeechView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var ttsDelay: Double

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                alert.ttsEnabled!
            }, set: { value in
                alert.ttsEnabled = value
                model.updateAlertsSettings()
            })) {
                Text("Enabled")
            }
            HStack {
                Text("Delay")
                Slider(
                    value: $ttsDelay,
                    in: 0 ... 5,
                    step: 0.5
                )
                .onChange(of: ttsDelay) { _ in
                    alert.ttsDelay = ttsDelay
                    model.updateAlertsSettings()
                }
                Text(String(formatOneDecimal(value: Float(ttsDelay))))
                    .frame(width: 35)
            }
        } header: {
            Text("Text to speech")
        }
    }
}

private struct AlertMediaView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var showImagePicker = false
    @State var showSoundPicker = false

    private func onImageUrl(url: URL) {
        model.alertMediaStorage.add(id: alert.imageId, url: url)
        model.updateAlertsSettings()
    }

    private func onSoundUrl(url: URL) {
        model.alertMediaStorage.add(id: alert.soundId, url: url)
        model.updateAlertsSettings()
    }

    var body: some View {
        Section {
            Button {
                showImagePicker = true
                model.onDocumentPickerUrl = onImageUrl
            } label: {
                HStack {
                    Spacer()
                    Text("Select image")
                    Spacer()
                }
            }
            .sheet(isPresented: $showImagePicker) {
                AlertPickerView(type: .gif)
            }
        } footer: {
            Text("Only GIF:s are supported.")
        }
        Section {
            Button {
                showSoundPicker = true
                model.onDocumentPickerUrl = onSoundUrl
            } label: {
                HStack {
                    Spacer()
                    Text("Select sound")
                    Spacer()
                }
            }
            .sheet(isPresented: $showSoundPicker) {
                AlertPickerView(type: .audio)
            }
        } footer: {
            Text("Only MP3 and WAV are supported.")
        }
    }
}

private struct TwitchFollowsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert

    var body: some View {
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
            AlertMediaView(alert: alert)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(alert: alert, fontSize: Float(alert.fontSize))
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.ttsDelay!)
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

    var body: some View {
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
            AlertMediaView(alert: alert)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(alert: alert, fontSize: Float(alert.fontSize))
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.ttsDelay!)
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
                NavigationLink(destination: TwitchFollowsView(alert: twitch.follows)) {
                    Text("Follows")
                }
                NavigationLink(destination: TwitchSubscriptionsView(alert: twitch.subscriptions)) {
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
