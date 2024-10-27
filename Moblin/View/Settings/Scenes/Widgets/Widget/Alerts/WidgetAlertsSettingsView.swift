import AVFAudio
import SDWebImageSwiftUI
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
    var alert: SettingsWidgetAlertsAlert
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
            NavigationLink {
                VoicesView(
                    textToSpeechLanguageVoices: alert.textToSpeechLanguageVoices!,
                    onVoiceChange: onVoiceChange
                )
            } label: {
                Text("Voices")
            }
        } header: {
            Text("Text to speech")
        }
    }
}

private struct AlertMediaView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert
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
            NavigationLink {
                AlertImageSelectorView(
                    alert: alert,
                    imageId: $imageId,
                    loopCount: Float(alert.imageLoopCount!)
                )
            } label: {
                TextItemView(name: "Image", value: getImageName(id: imageId))
            }
            NavigationLink {
                AlertSoundSelectorView(alert: alert, soundId: $soundId)
            } label: {
                TextItemView(name: "Sound", value: getSoundName(id: soundId))
            }
        } header: {
            Text("Media")
        }
    }
}

private struct AlertPositionFaceView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert
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
                alert.facePosition!.x,
                alert.facePosition!.y,
                alert.facePosition!.width,
                alert.facePosition!.height
            )
        }
    }

    private func createFacePositionPathAndUpdateImage(size: CGSize) -> Path {
        let (xTopLeft, yTopLeft, xBottomRight, yBottomRight) = calculatePositioningRectangle(
            facePositionAnchorPoint,
            alert.facePosition!.x,
            alert.facePosition!.y,
            alert.facePosition!.width,
            alert.facePosition!.height,
            facePosition,
            size,
            facePositionOffset
        )
        alert.facePosition!.x = xTopLeft
        alert.facePosition!.y = yTopLeft
        alert.facePosition!.width = xBottomRight - xTopLeft
        alert.facePosition!.height = yBottomRight - yTopLeft
        let xPoints = CGFloat(alert.facePosition!.x) * size.width
        let yPoints = CGFloat(alert.facePosition!.y) * size.height
        let widthPoints = CGFloat(alert.facePosition!.width) * size.width
        let heightPoints = CGFloat(alert.facePosition!.height) * size.height
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
    var alert: SettingsWidgetAlertsAlert
    @State var positionType: String

    var body: some View {
        Section {
            Picker("Type", selection: $positionType) {
                ForEach(alertPositionTypes, id: \.self) { type in
                    Text(type)
                }
            }
            .onChange(of: positionType) { _ in
                alert.positionType = SettingsWidgetAlertPositionType.fromString(value: positionType)
                model.updateAlertsSettings()
                model.objectWillChange.send()
            }
        } header: {
            Text("Position")
        }
        Section {
            switch SettingsWidgetAlertPositionType.fromString(value: positionType) {
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
    var alert: SettingsWidgetAlertsAlert

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
            AlertPositionView(alert: alert, positionType: alert.positionType!.toString())
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
                        user_name: testNames.randomElement()!
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
    }
}

private struct TwitchSubscriptionsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert

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
            AlertPositionView(alert: alert, positionType: alert.positionType!.toString())
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
                        user_name: testNames.randomElement()!,
                        tier: "2000",
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
    }
}

private struct TwitchRaidsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert

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
            AlertPositionView(alert: alert, positionType: alert.positionType!.toString())
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
                    let event = TwitchEventSubChannelRaidEvent(
                        from_broadcaster_user_name: testNames.randomElement()!,
                        viewers: .random(in: 1 ..< 1000)
                    )
                    model.testAlert(alert: .twitchRaid(event))
                }, label: {
                    HStack {
                        Spacer()
                        Text("Test")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("Raids")
    }
}

private func formatTitle(cheerBit: SettingsWidgetAlertsCheerBitsAlert) -> String {
    let bits = countFormatter.format(cheerBit.bits)
    switch cheerBit.comparisonOperator {
    case .equal:
        if cheerBit.bits == 1 {
            return "Cheer \(bits) bit"
        } else {
            return "Cheer \(bits) bits"
        }
    case .greaterEqual:
        return "Cheer \(bits)+ bits"
    }
}

private struct TwitchCheerView: View {
    @EnvironmentObject var model: Model
    var cheerBit: SettingsWidgetAlertsCheerBitsAlert

    private var alert: SettingsWidgetAlertsAlert {
        return cheerBit.alert
    }

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
            AlertPositionView(alert: alert, positionType: alert.positionType!.toString())
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
                    let event = TwitchEventSubChannelCheerEvent(
                        user_name: testNames.randomElement()!,
                        message: "A test message!",
                        bits: cheerBit.bits
                    )
                    model.testAlert(alert: .twitchCheer(event))
                }, label: {
                    HStack {
                        Spacer()
                        Text("Test")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle(formatTitle(cheerBit: cheerBit))
    }
}

private struct TwitchCheerBitsView: View {
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert]

    var body: some View {
        Form {
            List {
                ForEach(cheerBits) { cheerBit in
                    NavigationLink {
                        TwitchCheerView(cheerBit: cheerBit)
                    } label: {
                        Text(formatTitle(cheerBit: cheerBit))
                    }
                }
            }
        }
        .navigationTitle("Cheers")
    }
}

private struct TwitchRewardView: View {
    @EnvironmentObject var model: Model
    var reward: SettingsStreamTwitchReward

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
            if model.stream.twitchRewards!.isEmpty {
                Text("No rewards found")
            } else {
                ForEach(model.stream.twitchRewards!) { reward in
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
    var twitch: SettingsWidgetAlertsTwitch

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
                    TwitchRaidsView(alert: twitch.raids!)
                } label: {
                    Text("Raids")
                }
                NavigationLink {
                    TwitchCheerBitsView(cheerBits: twitch.cheerBits!)
                } label: {
                    Text("Cheers")
                }
                if model.database.debug!.twitchRewards! {
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
    var command: SettingsWidgetAlertsChatBotCommand

    private var alert: SettingsWidgetAlertsAlert {
        command.alert
    }

    private func onSubmit(value: String) {
        command.name = value.lowercased().trim().replacingOccurrences(
            of: "\\s",
            with: "",
            options: .regularExpression
        )
        model.updateAlertsSettings()
    }

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
            Section {
                NavigationLink {
                    TextEditView(
                        title: String(localized: "Name"),
                        value: command.name,
                        onSubmit: onSubmit
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Name"),
                        value: command.name
                    )
                }
            } footer: {
                Text("Trigger with chat message '!moblin alert \(command.name)'")
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertPositionView(alert: alert, positionType: alert.positionType!.toString())
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
                    model.testAlert(alert: .chatBotCommand(command.name, testNames.randomElement()!))
                }, label: {
                    HStack {
                        Spacer()
                        Text("Test")
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle("Command")
    }
}

private struct WidgetAlertsSettingsChatBotView: View {
    @EnvironmentObject var model: Model
    var chatBot: SettingsWidgetAlertsChatBot

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(chatBot.commands) { command in
                        NavigationLink {
                            ChatBotCommandView(command: command)
                        } label: {
                            Text(command.name.capitalized)
                        }
                    }
                    .onDelete(perform: { indexes in
                        chatBot.commands.remove(atOffsets: indexes)
                        model.updateAlertsSettings()
                    })
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

struct WidgetAlertsSettingsView: View {
    var widget: SettingsWidget

    var body: some View {
        Section {
            NavigationLink {
                WidgetAlertsSettingsTwitchView(twitch: widget.alerts!.twitch!)
            } label: {
                Text("Twitch")
            }
            NavigationLink {
                WidgetAlertsSettingsChatBotView(chatBot: widget.alerts!.chatBot!)
            } label: {
                Text("Chat bot")
            }
        }
    }
}
