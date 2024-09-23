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

private enum AnchorPoint {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
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

    private func calculateFacePositionAnchorPoint(location: CGPoint, size: CGSize) -> (AnchorPoint?, CGSize) {
        let x = location.x / size.width
        let y = location.y / size.height
        let xTopLeft = alert.facePosition!.x
        let yTopLeft = alert.facePosition!.y
        let xBottomRight = alert.facePosition!.x + alert.facePosition!.width
        let yBottomRight = alert.facePosition!.y + alert.facePosition!.height
        let xCenter = xTopLeft + alert.facePosition!.width / 2
        let yCenter = yTopLeft + alert.facePosition!.height / 2
        let xCenterTopLeft = xTopLeft + alert.facePosition!.width / 4
        let yCenterTopLeft = yTopLeft + alert.facePosition!.height / 4
        let xCenterBottomRight = xBottomRight - alert.facePosition!.width / 4
        let yCenterBottomRight = yBottomRight - alert.facePosition!.height / 4
        if x > xCenterTopLeft && x < xCenterBottomRight && y > yCenterTopLeft && y < yCenterBottomRight {
            return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
        } else if x + 0.1 < xTopLeft || x > xBottomRight + 0.1 || y + 0.1 < yTopLeft || y > yBottomRight +
            0.1
        {
            return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
        } else if x < xCenterTopLeft && y < yCenterTopLeft {
            return (.topLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yTopLeft - y)))
        } else if x > xCenterBottomRight && y < yCenterTopLeft {
            return (.topRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yTopLeft - y)))
        } else if x < xCenterTopLeft && y > yCenterBottomRight {
            return (.bottomLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yBottomRight - y)))
        } else if x > xCenterBottomRight && y > yCenterBottomRight {
            return (.bottomRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yBottomRight - y)))
        } else {
            return (nil, .zero)
        }
    }

    private func updateFacePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if facePositionAnchorPoint == nil {
            (facePositionAnchorPoint, facePositionOffset) = calculateFacePositionAnchorPoint(
                location: location,
                size: size
            )
        }
    }

    private func createFacePositionPathAndUpdateImage(size: CGSize) -> Path {
        var xTopLeft = alert.facePosition!.x
        var yTopLeft = alert.facePosition!.y
        var xBottomRight = xTopLeft + alert.facePosition!.width
        var yBottomRight = yTopLeft + alert.facePosition!.height
        let facePositionX = ((facePosition.x) / size.width + facePositionOffset.width)
            .clamped(to: 0 ... 1)
        let facePositionY = ((facePosition.y) / size.height + facePositionOffset.height)
            .clamped(to: 0 ... 1)
        let minimumWidth = 0.05
        let minimumHeight = 0.04
        switch facePositionAnchorPoint {
        case .topLeft:
            if facePositionX + minimumWidth < xBottomRight {
                xTopLeft = facePositionX
            }
            if facePositionY + minimumHeight < yBottomRight {
                yTopLeft = facePositionY
            }
        case .topRight:
            if facePositionX > xTopLeft + minimumWidth {
                xBottomRight = facePositionX
            }
            if facePositionY + minimumHeight < yBottomRight {
                yTopLeft = facePositionY
            }
        case .bottomLeft:
            if facePositionX + minimumWidth < xBottomRight {
                xTopLeft = facePositionX
            }
            if facePositionY > yTopLeft + minimumHeight {
                yBottomRight = facePositionY
            }
        case .bottomRight:
            if facePositionX > xTopLeft + minimumWidth {
                xBottomRight = facePositionX
            }
            if facePositionY > yTopLeft + minimumHeight {
                yBottomRight = facePositionY
            }
        case .center:
            let halfWidth = alert.facePosition!.width / 2
            let halfHeight = alert.facePosition!.height / 2
            var x = alert.facePosition!.x
            var y = alert.facePosition!.y
            if facePositionX - halfWidth >= 0 && facePositionX + halfWidth <= 1 {
                x = facePositionX - halfWidth
            }
            if facePositionY - halfHeight >= 0 && facePositionY + halfHeight <= 1 {
                y = facePositionY - halfHeight
            }
            xTopLeft = x
            yTopLeft = y
            xBottomRight = x + alert.facePosition!.width
            yBottomRight = y + alert.facePosition!.height
        case nil:
            break
        }
        alert.facePosition!.x = xTopLeft
        alert.facePosition!.y = yTopLeft
        alert.facePosition!.width = xBottomRight - xTopLeft
        alert.facePosition!.height = yBottomRight - yTopLeft
        let xPoints = CGFloat(alert.facePosition!.x) * size.width
        let yPoints = CGFloat(alert.facePosition!.y) * size.height
        let widthPoints = CGFloat(alert.facePosition!.width) * size.width
        let heightPoints = CGFloat(alert.facePosition!.height) * size.height
        var path = Path()
        path.move(to: .init(x: xPoints, y: yPoints))
        path.addLine(to: .init(x: xPoints + widthPoints, y: yPoints))
        path.addLine(to: .init(x: xPoints + widthPoints, y: yPoints + heightPoints))
        path.addLine(to: .init(x: xPoints, y: yPoints + heightPoints))
        path.addLine(to: .init(x: xPoints, y: yPoints))
        path.addEllipse(in: .init(x: xPoints - 5, y: yPoints - 5, width: 10, height: 10))
        path.addEllipse(in: .init(x: xPoints + widthPoints - 5, y: yPoints - 5, width: 10, height: 10))
        path.addEllipse(in: .init(
            x: xPoints + widthPoints - 5,
            y: yPoints + heightPoints - 5,
            width: 10,
            height: 10
        ))
        path.addEllipse(in: .init(x: xPoints - 5, y: yPoints + heightPoints - 5, width: 10, height: 10))
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
        .toolbar {
            SettingsToolbar()
        }
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
                    NavigationLink(destination: TwitchRewardView(reward: reward)) {
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
                NavigationLink(destination: TwitchRaidsView(alert: twitch.raids!)) {
                    Text("Raids")
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
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Name"),
                    value: command.name,
                    onSubmit: onSubmit
                )) {
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
        .toolbar {
            SettingsToolbar()
        }
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
                        NavigationLink(destination: ChatBotCommandView(command: command)) {
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
            NavigationLink(destination: WidgetAlertsSettingsChatBotView(chatBot: widget.alerts!.chatBot!)) {
                Text("Chat bot")
            }
        }
    }
}

struct WidgetVideoSettingsView: View {
    var widget: SettingsWidget

    var body: some View {
        Section {
            Text("Video source...")
        }
    }
}
