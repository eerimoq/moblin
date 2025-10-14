import AVFAudio
import PhotosUI
import SDWebImageSwiftUI
import SwiftUI
import UniformTypeIdentifiers

let alertTestNames = ["Mark", "Natasha", "Pedro", "Anna"]

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

struct AlertTextToSpeechView: View {
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
                    step: 0.5,
                    label: {
                        EmptyView()
                    }
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

struct AlertMediaView: View {
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

struct AlertPositionView: View {
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
                        model.testAlert(alert: .chatBotCommand(name, alertTestNames.randomElement()!))
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
                TwitchLogoAndNameView()
            }
            NavigationLink {
                WidgetAlertsSettingsKickView(kick: widget.alerts.kick)
            } label: {
                KickLogoAndNameView()
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
