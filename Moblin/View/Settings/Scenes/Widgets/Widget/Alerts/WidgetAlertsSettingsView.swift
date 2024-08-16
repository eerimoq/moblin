import AVFAudio
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
    @State var fontDesign: String
    @State var fontWeight: String

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
                Picker("", selection: $fontDesign) {
                    ForEach(textWidgetFontDesigns, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: fontDesign) {
                    alert.fontDesign = SettingsFontDesign.fromString(value: $0)
                    model.updateAlertsSettings()
                }
            }
            HStack {
                Text("Weight")
                Spacer()
                Picker("", selection: $fontWeight) {
                    ForEach(textWidgetFontWeights, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: fontWeight) {
                    alert.fontWeight = SettingsFontWeight.fromString(value: $0)
                    model.updateAlertsSettings()
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

private func loadImage(model: Model, imageId: UUID) -> UIImage? {
    if let data = model.alertMediaStorage.tryRead(id: imageId) {
        return UIImage(data: data)!
    } else {
        return nil
    }
}

private struct CustomImageView: View {
    @EnvironmentObject var model: Model
    var media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var image: UIImage?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        image = loadImage(model: model, imageId: media.id)
        model.updateAlertsSettings()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: media.name,
                    onSubmit: {
                        media.name = $0
                    }
                )
            }
            Section {
                Button {
                    showPicker = true
                    model.onDocumentPickerUrl = onUrl
                } label: {
                    HStack {
                        Spacer()
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 1920 / 6, height: 1080 / 6)
                        } else {
                            Text("Select image")
                        }
                        Spacer()
                    }
                }
                .sheet(isPresented: $showPicker) {
                    AlertPickerView(type: .gif)
                }
            } footer: {
                Text("Only GIF:s are supported.")
            }
        }
        .navigationTitle("Image")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct ImageGalleryView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.bundledImages) { image in
                        Text(image.name)
                    }
                }
            } header: {
                Text("Bundled")
            }
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.customImages) { image in
                        NavigationLink(destination: CustomImageView(
                            media: image,
                            image: loadImage(model: model, imageId: image.id)
                        )) {
                            Text(image.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.alertsMediaGallery!.customImages.remove(atOffsets: offsets)
                        model.fixAlertMedias()
                    })
                }
                Button(action: {
                    let image = SettingsAlertsMediaGalleryItem(name: "My image")
                    model.database.alertsMediaGallery!.customImages.append(image)
                    model.objectWillChange.send()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Add")
                        Spacer()
                    }
                })
            } header: {
                Text("Custom")
            } footer: {
                Text("Add your own images.")
            }
        }
        .navigationTitle("Gallery")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct ImageSelectorView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var imageId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $imageId) {
                    ForEach(model.getAllAlertImages()) {
                        Text($0.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: imageId) {
                    alert.imageId = $0
                    model.updateAlertsSettings()
                }
            }
            Section {
                NavigationLink(destination: ImageGalleryView()) {
                    Text("Gallery")
                }
            }
        }
        .navigationTitle("Image")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private func loadSound(model: Model, soundId: UUID) -> AVAudioPlayer? {
    let url = model.alertMediaStorage.makePath(id: soundId)
    return try? AVAudioPlayer(contentsOf: url)
}

private struct CustomSoundView: View {
    @EnvironmentObject var model: Model
    var media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var audioPlayer: AVAudioPlayer?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        audioPlayer = loadSound(model: model, soundId: media.id)
        model.updateAlertsSettings()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: media.name,
                    onSubmit: {
                        media.name = $0
                    }
                )
            }
            Section {
                if let audioPlayer {
                    Button {
                        audioPlayer.play()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Play")
                            Spacer()
                        }
                    }
                }
            }
            Section {
                Button {
                    showPicker = true
                    model.onDocumentPickerUrl = onUrl
                } label: {
                    HStack {
                        Spacer()
                        if audioPlayer != nil {
                            Text("Select another sound")
                        } else {
                            Text("Select sound")
                        }
                        Spacer()
                    }
                }
                .sheet(isPresented: $showPicker) {
                    AlertPickerView(type: .audio)
                }
            }
        }
        .navigationTitle("Sound")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct SoundGalleryView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.bundledSounds) { sound in
                        Text(sound.name)
                    }
                }
            } header: {
                Text("Bundled")
            }
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.customSounds) { sound in
                        NavigationLink(destination: CustomSoundView(
                            media: sound,
                            audioPlayer: loadSound(model: model, soundId: sound.id)
                        )) {
                            Text(sound.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.alertsMediaGallery!.customSounds.remove(atOffsets: offsets)
                        model.fixAlertMedias()
                    })
                }
                Button(action: {
                    let sound = SettingsAlertsMediaGalleryItem(name: "My sound")
                    model.database.alertsMediaGallery!.customSounds.append(sound)
                    model.objectWillChange.send()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Add")
                        Spacer()
                    }
                })
            } header: {
                Text("Custom")
            } footer: {
                Text("Add your own sounds.")
            }
        }
        .navigationTitle("Gallery")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct SoundSelectorView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var soundId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $soundId) {
                    ForEach(model.getAllAlertSounds()) {
                        Text($0.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: soundId) {
                    alert.soundId = $0
                    model.updateAlertsSettings()
                }
            }
            Section {
                NavigationLink(destination: SoundGalleryView()) {
                    Text("Gallery")
                }
            }
        }
        .navigationTitle("Sound")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct AlertMediaView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert

    private func getImageName(id: UUID?) -> String {
        return model.getAllAlertImages().first(where: { $0.id == id })?.name ?? ""
    }

    private func getSoundName(id: UUID?) -> String {
        return model.getAllAlertSounds().first(where: { $0.id == id })?.name ?? ""
    }

    var body: some View {
        Section {
            NavigationLink(destination: ImageSelectorView(alert: alert, imageId: alert.imageId)) {
                TextItemView(name: "Image", value: getImageName(id: alert.imageId))
            }
            NavigationLink(destination: SoundSelectorView(alert: alert, soundId: alert.soundId)) {
                TextItemView(name: "Sound", value: getSoundName(id: alert.soundId))
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
            AlertMediaView(alert: alert)
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
            AlertMediaView(alert: alert)
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
            NavigationLink(destination: WidgetAlertsSettingsTwitchView(twitch: widget.alerts!.twitch!)) {
                Text("Twitch")
            }
        }
    }
}
