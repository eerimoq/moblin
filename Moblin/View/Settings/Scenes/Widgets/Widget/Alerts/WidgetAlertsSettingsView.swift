import AVFAudio
import PhotosUI
import SDWebImageSwiftUI
import SwiftUI
import UniformTypeIdentifiers

private let testNames = ["Mark", "Natasha", "Pedro", "Anna"]

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
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    @State var ttsDelay: Double
    @State var rate: Float = 0.4
    @State var volume: Float = 0.6

    private func onVoiceChange(languageCode: String, voice: String) {
        alert.textToSpeechLanguageVoices[languageCode] = voice
        model.updateAlertsSettings()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                alert.textToSpeechEnabled
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
                Text(String(formatOneDecimal(Float(ttsDelay))))
                    .frame(width: 35)
            }
            NavigationLink {
                VoicesView(
                    textToSpeechLanguageVoices: $alert.textToSpeechLanguageVoices,
                    onVoiceChange: onVoiceChange,
                    rate: $rate,
                    volume: $volume
                )
            } label: {
                Text("Voices")
            }
        } header: {
            Text("Text to speech")
        }
    }
}

private func getImageName(model: Model, id: UUID?) -> String {
    return model.getAllAlertImages().first(where: { $0.id == id })?.name ?? ""
}

private func getSoundName(model: Model, id: UUID?) -> String {
    return model.getAllAlertSounds().first(where: { $0.id == id })?.name ?? ""
}

private struct AlertMediaView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    @State var imageId: UUID
    @State var soundId: UUID

    var body: some View {
        Section {
            NavigationLink {
                AlertImageSelectorView(
                    alert: alert,
                    imageId: $imageId,
                    loopCount: Float(alert.imageLoopCount)
                )
            } label: {
                TextItemView(name: "Image", value: getImageName(model: model, id: imageId))
            }
            NavigationLink {
                AlertSoundSelectorView(alert: alert, soundId: $soundId)
            } label: {
                TextItemView(name: "Sound", value: getSoundName(model: model, id: soundId))
            }
        } header: {
            Text("Media")
        }
    }
}

private struct AlertPositionFaceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    @State private var facePosition: CGPoint = .init(x: 100, y: 100)
    @State private var facePositionOffset: CGSize = .init(width: 0, height: 0)
    @State private var facePositionAnchorPoint: AnchorPoint?
    @State private var imageWidth: CGFloat = 100
    @State private var imageHeight: CGFloat = 100
    @State private var imageOffset: CGSize = .init(width: 0, height: 0)

    private func updateFacePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if facePositionAnchorPoint == nil {
            (facePositionAnchorPoint, facePositionOffset) = calculatePositioningAnchorPoint(
                location,
                size,
                alert.facePosition.x,
                alert.facePosition.y,
                alert.facePosition.width,
                alert.facePosition.height
            )
        }
    }

    private func createFacePositionPathAndUpdateImage(size: CGSize) -> Path {
        let (xTopLeft, yTopLeft, xBottomRight, yBottomRight) = calculatePositioningRectangle(
            facePositionAnchorPoint,
            alert.facePosition.x,
            alert.facePosition.y,
            alert.facePosition.width,
            alert.facePosition.height,
            facePosition,
            size,
            facePositionOffset
        )
        alert.facePosition.x = xTopLeft
        alert.facePosition.y = yTopLeft
        alert.facePosition.width = xBottomRight - xTopLeft
        alert.facePosition.height = yBottomRight - yTopLeft
        let xPoints = CGFloat(alert.facePosition.x) * size.width
        let yPoints = CGFloat(alert.facePosition.y) * size.height
        let widthPoints = CGFloat(alert.facePosition.width) * size.width
        let heightPoints = CGFloat(alert.facePosition.height) * size.height
        let path = drawPositioningRectangle(xPoints, yPoints, widthPoints, heightPoints)
        imageWidth = widthPoints
        imageHeight = heightPoints
        imageOffset = .init(
            width: xPoints + widthPoints / 2 - size.width / 2,
            height: yPoints + heightPoints / 2 - size.height / 2
        )
        return path
    }

    var body: some View {
        ZStack {
            Image("AlertFace")
                .resizable()
                .scaledToFit()
            if let image = loadAlertImage(model: model, imageId: alert.imageId) {
                AnimatedImage(data: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageWidth, height: imageHeight)
                    .offset(imageOffset)
                    .allowsHitTesting(false)
            }
            GeometryReader { reader in
                Canvas { context, size in
                    context.stroke(
                        createFacePositionPathAndUpdateImage(size: size),
                        with: .color(.black),
                        lineWidth: 1.5
                    )
                }
                .padding([.top, .bottom], 6)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            facePosition = value.location
                            let size = CGSize(width: reader.size.width, height: reader.size.height - 12)
                            updateFacePositionAnchorPoint(location: facePosition, size: size)
                        }
                        .onEnded { _ in
                            facePositionAnchorPoint = nil
                        }
                )
            }
        }
    }
}

private struct AlertPositionView: View {
    @EnvironmentObject var model: Model
    let alert: SettingsWidgetAlertsAlert
    @State var positionType: SettingsWidgetAlertPositionType

    var body: some View {
        Section {
            Picker("Type", selection: $positionType) {
                ForEach(SettingsWidgetAlertPositionType.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: positionType) { _ in
                alert.positionType = positionType
                model.updateAlertsSettings()
                model.objectWillChange.send()
            }
        } header: {
            Text("Position")
        }
        Section {
            switch positionType {
            case .face:
                AlertPositionFaceView(alert: alert)
            default:
                EmptyView()
            }
        }
    }
}

private struct TwitchFollowsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

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
                Button {
                    let event = TwitchEventSubNotificationChannelFollowEvent(
                        user_name: testNames.randomElement()!
                    )
                    model.testAlert(alert: .twitchFollow(event))
                } label: {
                    HCenter {
                        Text("Test")
                    }
                }
            }
        }
        .navigationTitle("Follows")
    }
}

private struct TwitchSubscriptionsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

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
                Button {
                    let event = TwitchEventSubNotificationChannelSubscribeEvent(
                        user_name: testNames.randomElement()!,
                        tier: "2000",
                        is_gift: false
                    )
                    model.testAlert(alert: .twitchSubscribe(event))
                } label: {
                    HCenter {
                        Text("Test")
                    }
                }
            }
        }
        .navigationTitle("Subscriptions")
    }
}

private struct TwitchRaidsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

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
                Button {
                    let event = TwitchEventSubChannelRaidEvent(
                        from_broadcaster_user_name: testNames.randomElement()!,
                        viewers: .random(in: 1 ..< 1000)
                    )
                    model.testAlert(alert: .twitchRaid(event))
                } label: {
                    HCenter {
                        Text("Test")
                    }
                }
            }
        }
        .navigationTitle("Raids")
    }
}

private func formatTitle(_ bits: Int, _ comparisonOperator: String) -> String {
    let bitsText = countFormatter.format(bits)
    switch SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: comparisonOperator) {
    case .equal:
        if bits == 1 {
            return "Cheer \(bitsText) bit"
        } else {
            return "Cheer \(bitsText) bits"
        }
    case .greaterEqual:
        return "Cheer \(bitsText)+ bits"
    default:
        return ""
    }
}

private struct TwitchCheerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let cheerBit: SettingsWidgetAlertsCheerBitsAlert
    @Binding var bits: Int
    @Binding var comparisonOperator: String

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
            TextEditNavigationView(title: String(localized: "Bits"),
                                   value: String(bits),
                                   onChange: { value in
                                       guard let bits = Int(value) else {
                                           return String(localized: "Not a number")
                                       }
                                       return nil
                                   },
                                   onSubmit: { value in
                                       guard let bits = Int(value) else {
                                           return
                                       }
                                       self.bits = bits
                                       cheerBit.bits = bits
                                       model.updateAlertsSettings()
                                   },
                                   keyboardType: .numbersAndPunctuation)
            HStack {
                Text("Comparison")
                Spacer()
                Picker("", selection: $comparisonOperator) {
                    ForEach(twitchCheerBitsAlertOperators, id: \.self) {
                        Text($0)
                    }
                }
            }
            .onChange(of: comparisonOperator) { _ in
                let comparisonOperator = SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: comparisonOperator)
                cheerBit.comparisonOperator = comparisonOperator ?? .greaterEqual
                model.updateAlertsSettings()
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
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
                Button {
                    let event = TwitchEventSubChannelCheerEvent(
                        user_name: testNames.randomElement()!,
                        message: "A test message!",
                        bits: cheerBit.bits
                    )
                    model.testAlert(alert: .twitchCheer(event))
                } label: {
                    HCenter {
                        Text("Test")
                    }
                }
            }
        }
        .navigationTitle(formatTitle(cheerBit.bits, cheerBit.comparisonOperator.rawValue))
    }
}

private struct TwitchCheerBitsItemView: View {
    let alert: SettingsWidgetAlertsAlert
    private let cheerBit: SettingsWidgetAlertsCheerBitsAlert
    @State private var bits: Int
    @State private var comparisonOperator: String

    init(alert: SettingsWidgetAlertsAlert, cheerBit: SettingsWidgetAlertsCheerBitsAlert) {
        self.alert = alert
        self.cheerBit = cheerBit
        bits = cheerBit.bits
        comparisonOperator = cheerBit.comparisonOperator.rawValue
    }

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            NavigationLink {
                TwitchCheerView(
                    alert: alert,
                    cheerBit: cheerBit,
                    bits: $bits,
                    comparisonOperator: $comparisonOperator
                )
            } label: {
                Text(formatTitle(bits, comparisonOperator))
            }
        }
    }
}

private struct TwitchCheerBitsView: View {
    @EnvironmentObject var model: Model
    let twitch: SettingsWidgetAlertsTwitch

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(twitch.cheerBits) { cheerBit in
                        TwitchCheerBitsItemView(alert: cheerBit.alert, cheerBit: cheerBit)
                    }
                    .onMove { froms, to in
                        twitch.cheerBits.move(fromOffsets: froms, toOffset: to)
                        model.updateAlertsSettings()
                    }
                    .onDelete { offsets in
                        twitch.cheerBits.remove(atOffsets: offsets)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let cheerBits = SettingsWidgetAlertsCheerBitsAlert()
                    twitch.cheerBits.append(cheerBits)
                    model.updateAlertsSettings()
                    model.objectWillChange.send()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("The first item that matches cheered bits will be played.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: "an item")
                }
            }
        }
        .navigationTitle("Cheers")
    }
}

private struct TwitchRewardView: View {
    @EnvironmentObject var model: Model
    let reward: SettingsStreamTwitchReward

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    reward.alert.enabled
                }, set: { value in
                    reward.alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            AlertMediaView(alert: reward.alert, imageId: reward.alert.imageId, soundId: reward.alert.soundId)
        }
        .navigationTitle(reward.title)
    }
}

private struct TwitchRewardsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            if model.stream.twitchRewards.isEmpty {
                Text("No rewards found")
            } else {
                ForEach(model.stream.twitchRewards) { reward in
                    NavigationLink {
                        TwitchRewardView(reward: reward)
                    } label: {
                        Text(reward.title)
                    }
                }
            }
        }
        .onAppear {
            model.fetchTwitchRewards()
        }
        .navigationTitle("Rewards")
    }
}

private struct WidgetAlertsSettingsTwitchView: View {
    @EnvironmentObject var model: Model
    let twitch: SettingsWidgetAlertsTwitch

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TwitchFollowsView(alert: twitch.follows)
                } label: {
                    Text("Follows")
                }
                NavigationLink {
                    TwitchSubscriptionsView(alert: twitch.subscriptions)
                } label: {
                    Text("Subscriptions")
                }
                NavigationLink {
                    TwitchRaidsView(alert: twitch.raids)
                } label: {
                    Text("Raids")
                }
                NavigationLink {
                    TwitchCheerBitsView(twitch: twitch)
                } label: {
                    Text("Cheers")
                }
                if model.database.debug.twitchRewards {
                    NavigationLink {
                        TwitchRewardsView()
                    } label: {
                        Text("Rewards")
                    }
                }
            }
        }
        .navigationTitle("Twitch")
    }
}

private struct ChatBotCommandView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let command: SettingsWidgetAlertsChatBotCommand
    @State var name: String
    // @State var imageType: String
    // @State var imageId: UUID
    // @State var soundId: UUID
    // @State var imagePlaygroundImageType: UUID

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
                                           onChange: { _ in nil },
                                           onSubmit: onSubmit)
                } footer: {
                    Text("Trigger with chat message '!moblin alert \(name)'")
                }
                // Section {
                //     Picker(selection: $imageType) {
                //         ForEach(chatBotCommandImageTypes, id: \.self) { type in
                //             Text(type)
                //         }
                //     } label: {
                //         Text("Type")
                //     }
                //     .onChange(of: imageType) { value in
                //         command.imageType = SettingsWidgetAlertsChatBotCommandImageType.fromString(value: value)
                //         model.updateAlertsSettings()
                //     }
                //     switch SettingsWidgetAlertsChatBotCommandImageType.fromString(value: imageType) {
                //     case .file:
                //         NavigationLink {
                //             AlertImageSelectorView(
                //                 alert: alert,
                //                 imageId: $imageId,
                //                 loopCount: Float(alert.imageLoopCount!)
                //             )
                //         } label: {
                //             TextItemView(
                //                 name: String(localized: "File"),
                //                 value: getImageName(model: model, id: imageId)
                //             )
                //         }
                //     case .imagePlayground:
                //         NavigationLink {
                //             AlertImagePlaygroundSelectorView(command: command, imageId:
                //             command.imagePlaygroundImageId!)
                //         } label: {
                //             Text("Image Playground")
                //         }
                //     }
                // } header: {
                //     Text("Image")
                // }
                // Section {
                //     NavigationLink {
                //         AlertSoundSelectorView(alert: alert, soundId: $soundId)
                //     } label: {
                //         TextItemView(name: "Sound", value: getSoundName(model: model, id: soundId))
                //     }
                // } header: {
                //     Text("Sound")
                // }
                AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
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
                    Button {
                        model.testAlert(alert: .chatBotCommand(name, testNames.randomElement()!))
                    } label: {
                        HCenter {
                            Text("Test")
                        }
                    }
                }
            }
            .navigationTitle("Command")
        } label: {
            Text(name.capitalized)
        }
    }
}

private struct WidgetAlertsSettingsChatBotView: View {
    @EnvironmentObject var model: Model
    let chatBot: SettingsWidgetAlertsChatBot

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chatBot.commands) { command in
                        ChatBotCommandView(
                            alert: command.alert,
                            command: command,
                            name: command.name /* ,
                             imageType: command.imageType!.toString(),
                             imageId: command.alert.imageId,
                             soundId: command.alert.soundId,
                             imagePlaygroundImageType: command.imagePlaygroundImageId! */
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
                    model.objectWillChange.send()
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

private struct SpeechToTextStringView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let string: SettingsWidgetAlertsSpeechToTextString
    @State var text: String

    private func onSubmit(value: String) {
        string.string = value
        text = value
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
                    TextEditNavigationView(title: String(localized: "String"),
                                           value: text,
                                           onChange: { _ in nil },
                                           onSubmit: onSubmit)
                } footer: {
                    Text("Trigger by saying '\(text)'.")
                }
                AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
                AlertPositionView(alert: alert, positionType: alert.positionType)
                Section {
                    Button {
                        model.testAlert(alert: .speechToTextString(string.id))
                    } label: {
                        HCenter {
                            Text("Test")
                        }
                    }
                }
            }
            .navigationTitle("String")
        } label: {
            Text(text)
        }
    }
}

private struct WidgetAlertsSettingsSpeechToTextView: View {
    @EnvironmentObject var model: Model
    let speechToText: SettingsWidgetAlertsSpeechToText

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(speechToText.strings) { string in
                        SpeechToTextStringView(alert: string.alert, string: string, text: string.string)
                    }
                    .onDelete { indexes in
                        speechToText.strings.remove(atOffsets: indexes)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let string = SettingsWidgetAlertsSpeechToTextString()
                    speechToText.strings.append(string)
                    model.fixAlertMedias()
                    model.updateAlertsSettings()
                    model.objectWillChange.send()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Trigger alerts when you say something.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a string"))
                }
            }
        }
        .navigationTitle("Speech to text")
    }
}

struct WidgetAlertsSettingsView: View {
    let widget: SettingsWidget

    var body: some View {
        Section {
            NavigationLink {
                WidgetAlertsSettingsTwitchView(twitch: widget.alerts.twitch)
            } label: {
                Text("Twitch")
            }
            NavigationLink {
                WidgetAlertsSettingsChatBotView(chatBot: widget.alerts.chatBot)
            } label: {
                Text("Chat bot")
            }
            NavigationLink {
                WidgetAlertsSettingsSpeechToTextView(speechToText: widget.alerts.speechToText)
            } label: {
                Text("Speech to text")
            }
        }
    }
}
