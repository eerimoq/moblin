import SwiftUI
import UniformTypeIdentifiers

private struct MicView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var mic: Mic

    var body: some View {
        NavigationLink {
            QuickButtonMicView(model: model, mics: mics, modelMic: mic)
        } label: {
            Label {
                HStack {
                    Text("Mic")
                    Spacer()
                    GrayTextView(text: mic.current.name)
                }
            } icon: {
                Image(systemName: "music.mic")
            }
        }
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    @ObservedObject var mic: Mic
    @ObservedObject var debug: SettingsDebug
    @ObservedObject var audio: SettingsAudio

    private func changeOutputChannel(value: String) -> String? {
        if Int(value) != nil {
            nil
        } else {
            String(localized: "Not a number")
        }
    }

    private func submitOutputChannel1(value: String) {
        guard let channel = Int(value) else {
            return
        }
        audio.outputToInputChannelsMap.channel1 = max(channel - 1, -1)
        model.reloadStreamIfEnabled(stream: stream)
    }

    private func submitOutputChannel2(value: String) {
        guard let channel = Int(value) else {
            return
        }
        audio.outputToInputChannelsMap.channel2 = max(channel - 1, -1)
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            if database.showAllSettings, stream !== fallbackStream {
                ShortcutSectionView {
                    NavigationLink {
                        StreamAudioSettingsView(
                            stream: stream,
                            bitrate: Float(stream.audioBitrate / 1000)
                        )
                    } label: {
                        Label("Audio", systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            }
            Section {
                MicView(model: model, mics: database.mics, mic: model.mic)
            }
            Section {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $mic.inputGain, in: 0.0 ... 1.0, step: 0.1)
                    Image(systemName: "speaker.wave.3.fill")
                }
                .disabled(mic.current.isAudioSession() && !mic.inputGainSettable)
                .onChange(of: mic.inputGain) { _ in
                    model.setInputGainIfSupported(inputGain: mic.inputGain)
                }
            } header: {
                Text("Input gain")
            } footer: {
                Text("Typically only supported by external mics.")
            }
            Section {
                HStack {
                    Image(systemName: "speaker.wave.1.fill")
                    Slider(value: $audio.gainDb, in: 0.0 ... 24.0, step: 1.0)
                        .onChange(of: audio.gainDb) { _ in
                            model.setAudioGain(gainDb: audio.gainDb)
                        }
                    Image(systemName: "speaker.wave.3.fill")
                    Text("\(formatOneDecimal(audio.gainDb)) dB")
                        .frame(width: 65)
                }
            } header: {
                Text("Output gain")
            } footer: {
                Text("0.0 dB by default, leaving the input level unchanged.")
            }
            Section {
                Toggle("Bluetooth output only", isOn: $debug.bluetoothOutputOnly)
                    .onChange(of: debug.bluetoothOutputOnly) { _ in
                        model.reloadAudioSession()
                    }
            } footer: {
                Text("Makes most Bluetooth speakers work better.")
            }
            Section {
                Toggle("Prefer stereo mic", isOn: $debug.preferStereoMic)
                    .onChange(of: debug.preferStereoMic) { _ in
                        if mic.current.isAudioSession() {
                            model.reloadAudioSession()
                            model.selectMicDefault(mic: mic.current)
                        }
                    }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Only works when front or back mic is selected.")
                    Text("")
                    Text("Switching between mono and stereo mics may not work.")
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Output channel 1"),
                    value: String(audio.outputToInputChannelsMap.channel1 + 1),
                    onChange: changeOutputChannel,
                    onSubmit: submitOutputChannel1
                )
                .disabled(model.isLive || model.isRecording)
                TextEditNavigationView(
                    title: String(localized: "Output channel 2"),
                    value: String(audio.outputToInputChannelsMap.channel2 + 1),
                    onChange: changeOutputChannel,
                    onSubmit: submitOutputChannel2
                )
                .disabled(model.isLive || model.isRecording)
            } header: {
                Text("Input to output channel mapping")
            } footer: {
                Text("Mono audio only uses output channel 1. Stereo audio uses both output channels.")
            }
            Section {
                Toggle("Mute loop sound", isOn: $audio.muteSoundEnabled)
                if audio.muteSoundEnabled {
                    NavigationLink {
                        MuteSoundSelectorView(
                            model: model,
                            soundId: $audio.muteSoundId
                        )
                        .environmentObject(model)
                    } label: {
                        HStack {
                            Text("Sound")
                            Spacer()
                            GrayTextView(text: getMuteSoundName(model: model, soundId: audio.muteSoundId))
                        }
                    }
                }
            } header: {
                Text("Mute feedback")
            } footer: {
                Text("Play a looping alert sound while the microphone is muted.")
            }
        }
        .navigationTitle("Audio")
    }
}

@MainActor
private func getMuteSoundName(model: Model, soundId: UUID?) -> String {
    if let soundId {
        model.getAllAlertSounds().first(where: { $0.id == soundId })?.name ?? String(localized: "-- None --")
    } else {
        model.getAllAlertSounds().first?.name ?? String(localized: "Notification 2")
    }
}

private struct MuteCustomSoundView: View {
    let model: Model
    let media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var audioPlayer: AudioPlayer?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        if let url = model.getAlertSoundUrl(soundId: media.id) {
            audioPlayer = try? AudioPlayer(contentsOf: url)
        }
        model.updateAlertsSettings()
        model.objectWillChange.send()
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
                    TextButtonView("Play") {
                        audioPlayer.play()
                    }
                }
            }
            Section {
                Button {
                    showPicker = true
                    model.onDocumentPickerUrl = onUrl
                } label: {
                    HCenter {
                        if audioPlayer != nil {
                            Text("Select another sound")
                        } else {
                            Text("Select sound")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            AlertPickerView(type: .audio)
                .environmentObject(model)
        }
        .onAppear {
            if let url = model.getAlertSoundUrl(soundId: media.id) {
                audioPlayer = try? AudioPlayer(contentsOf: url)
            }
        }
        .navigationTitle(media.name)
    }
}

private struct MuteSoundSelectorView: View {
    let model: Model
    @Binding var soundId: UUID?
    @State private var previewPlayer: AudioPlayer?
    @State private var showPicker = false
    @State private var newlyCreatedSound: SettingsAlertsMediaGalleryItem?

    private func onUrl(url: URL) {
        guard let sound = newlyCreatedSound else { return }
        model.alertMediaStorage.add(id: sound.id, url: url)
        let fileName = url.deletingPathExtension().lastPathComponent
        sound.name = fileName
        soundId = sound.id
        model.updateAlertsSettings()
        model.objectWillChange.send()
    }

    private func deleteSound(at offsets: IndexSet) {
        model.database.alertsMediaGallery.customSounds.remove(atOffsets: offsets)
        model.fixAlertMedias()
        model.objectWillChange.send()
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $soundId) {
                    ForEach(model.getAllAlertSounds()) { sound in
                        HStack {
                            Text(sound.name)
                            Spacer()
                            Button {
                                guard let url = model.getAlertSoundUrl(soundId: sound.id) else {
                                    return
                                }
                                previewPlayer = try? AudioPlayer(contentsOf: url)
                                previewPlayer?.play()
                            } label: {
                                Image(systemName: "play.fill")
                            }
                        }
                        .tag(sound.id as UUID?)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Select Sound")
            }

            Section {
                List {
                    ForEach(model.database.alertsMediaGallery.customSounds) { sound in
                        NavigationLink {
                            MuteCustomSoundView(model: model, media: sound)
                                .environmentObject(model)
                        } label: {
                            Text(sound.name)
                        }
                        .contextMenuDeleteButton {
                            if let offsets = makeOffsets(
                                model.database.alertsMediaGallery.customSounds,
                                sound.id
                            ) {
                                deleteSound(at: offsets)
                            }
                        }
                    }
                    .onDelete(perform: deleteSound)
                }
                TextButtonView("Add custom sound") {
                    let sound = SettingsAlertsMediaGalleryItem(name: "Custom Sound")
                    model.database.alertsMediaGallery.customSounds.append(sound)
                    newlyCreatedSound = sound
                    model.onDocumentPickerUrl = onUrl
                    showPicker = true
                }
            } header: {
                Text("Custom Sounds")
            } footer: {
                Text("Add custom sounds and select a file from your device files.")
            }
        }
        .sheet(isPresented: $showPicker) {
            AlertPickerView(type: .audio)
                .environmentObject(model)
        }
        .onDisappear {
            previewPlayer = nil
        }
        .navigationTitle("Sound")
    }
}
