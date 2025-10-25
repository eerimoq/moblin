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

    private func onVoiceChange(languageCode: String, voice: SettingsVoice) {
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
                    volume: $volume,
                    ttsMonsterApiToken: ""
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

private struct AiResponseView: View {
    let model: Model
    @ObservedObject var alerts: SettingsWidgetAlerts
    @ObservedObject var ai: SettingsOpenAi

    var body: some View {
        NavigationLink {
            Form {
                OpenAiSettingsView(ai: ai)
                    .onChange(of: ai.baseUrl) { _ in
                        model.updateAlertsSettings()
                    }
                    .onChange(of: ai.apiKey) { _ in
                        model.updateAlertsSettings()
                    }
                    .onChange(of: ai.model) { _ in
                        model.updateAlertsSettings()
                    }
                    .onChange(of: ai.personality) { _ in
                        model.updateAlertsSettings()
                    }
            }
            .navigationTitle("AI response")
        } label: {
            Toggle("AI response", isOn: $alerts.aiEnabled)
                .disabled(!ai.isConfigured())
                .onChange(of: alerts.aiEnabled) { _ in
                    model.updateAlertsSettings()
                }
        }
    }
}

struct WidgetAlertsSettingsView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Section {
            NavigationLink {
                WidgetAlertsTwitchSettingsView(twitch: widget.alerts.twitch)
            } label: {
                TwitchLogoAndNameView()
            }
            NavigationLink {
                WidgetAlertsKickSettingsView(kick: widget.alerts.kick)
            } label: {
                KickLogoAndNameView()
            }
            NavigationLink {
                WidgetAlertsChatBotSettingsView(chatBot: widget.alerts.chatBot)
            } label: {
                Text("Chat bot")
            }
            NavigationLink {
                WidgetAlertsSpeechToTextSettingsView(speechToText: widget.alerts.speechToText)
            } label: {
                Text("Speech to text")
            }
        }
        AiResponseView(model: model,
                       alerts: widget.alerts,
                       ai: widget.alerts.ai)
        // TtsMonsterSettingsView(ttsMonster: widget.alerts.ttsMonster)
    }
}
