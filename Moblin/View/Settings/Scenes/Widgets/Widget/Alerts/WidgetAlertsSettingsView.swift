import AVFAudio
import SwiftUI
import UniformTypeIdentifiers

private let testNames: [String] = ["Mark", "Natasha", "Pedro", "Anna"]

struct AlertPickerView: UIViewControllerRepresentable {
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

private struct AlertTextToSpeechView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var ttsDelay: Double

    private func onVoiceChange(languageCode: String, voice: String) {
        alert.textToSpeechLanguageVoices![languageCode] = voice
        model.updateAlertsSettings()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                alert.textToSpeechEnabled!
            }, set: { value in
                alert.textToSpeechEnabled = value
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
                    alert.textToSpeechDelay = ttsDelay
                    model.updateAlertsSettings()
                }
                Text(String(formatOneDecimal(value: Float(ttsDelay))))
                    .frame(width: 35)
            }
            NavigationLink(destination: VoicesView(
                textToSpeechLanguageVoices: alert.textToSpeechLanguageVoices!,
                onVoiceChange: onVoiceChange
            )) {
                Text("Voices")
            }
        } header: {
            Text("Text to speech")
        }
    }
}

private struct AlertMediaView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var imageId: UUID
    @State var soundId: UUID

    private func getImageName(id: UUID?) -> String {
        return model.getAllAlertImages().first(where: { $0.id == id })?.name ?? ""
    }

    private func getSoundName(id: UUID?) -> String {
        return model.getAllAlertSounds().first(where: { $0.id == id })?.name ?? ""
    }

    var body: some View {
        Section {
            NavigationLink(destination: AlertImageSelectorView(
                alert: alert,
                imageId: $imageId,
                loopCount: Float(alert.imageLoopCount!)
            )) {
                TextItemView(name: "Image", value: getImageName(id: imageId))
            }
            NavigationLink(destination: AlertSoundSelectorView(alert: alert, soundId: $soundId)) {
                TextItemView(name: "Sound", value: getSoundName(id: soundId))
            }
        } header: {
            Text("Media")
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
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign.toString(),
                fontWeight: alert.fontWeight.toString()
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay!)
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
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign.toString(),
                fontWeight: alert.fontWeight.toString()
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay!)
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

private struct TwitchRewardView: View {
    @EnvironmentObject var model: Model
    var name: String

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    true
                }, set: { _ in
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
        }
        .navigationTitle(name)
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct TwitchRewardsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            if model.stream.twitchRewards!.isEmpty {
                Text("No rewards found")
            } else {
                ForEach(model.stream.twitchRewards!) { reward in
                    NavigationLink(destination: TwitchRewardView(name: reward.title)) {
                        Text(reward.title)
                    }
                }
            }
        }
        .onAppear {
            model.fetchTwitchRewards()
        }
        .navigationTitle("Rewards")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct WidgetAlertsSettingsTwitchView: View {
    @EnvironmentObject var model: Model
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
                if model.database.debug!.twitchRewards! {
                    NavigationLink(destination: TwitchRewardsView()) {
                        Text("Rewards")
                    }
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
