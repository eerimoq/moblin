import AVFAudio
import SwiftUI
import UniformTypeIdentifiers

private func loadSound(model: Model, soundId: UUID) -> AVAudioPlayer? {
    var url: URL?
    if let bundledSound = model.database.alertsMediaGallery.bundledSounds.first(where: { $0.id == soundId }) {
        url = Bundle.main.url(forResource: "Alerts.bundle/\(bundledSound.name)", withExtension: "mp3")
    } else {
        url = model.alertMediaStorage.makePath(id: soundId)
    }
    guard let url else {
        return nil
    }
    return try? AVAudioPlayer(contentsOf: url)
}

private struct CustomSoundView: View {
    @EnvironmentObject var model: Model
    let media: SettingsAlertsMediaGalleryItem
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
                .sheet(isPresented: $showPicker) {
                    AlertPickerView(type: .audio)
                }
            }
        }
        .navigationTitle("Sound")
    }
}

private struct SoundGalleryView: View {
    @EnvironmentObject var model: Model
    let alert: SettingsWidgetAlertsAlert
    @Binding var soundId: UUID

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery.customSounds) { sound in
                        NavigationLink {
                            CustomSoundView(
                                media: sound,
                                audioPlayer: loadSound(model: model, soundId: sound.id)
                            )
                        } label: {
                            Text(sound.name)
                        }
                    }
                    .onDelete { offsets in
                        model.database.alertsMediaGallery.customSounds.remove(atOffsets: offsets)
                        model.fixAlertMedias()
                        soundId = alert.soundId
                    }
                }
                TextButtonView("Add") {
                    let sound = SettingsAlertsMediaGalleryItem(name: "My sound")
                    model.database.alertsMediaGallery.customSounds.append(sound)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a sound"))
            }
        }
        .navigationTitle("My sounds")
    }
}

private var player: AVAudioPlayer?

struct AlertSoundSelectorView: View {
    @EnvironmentObject var model: Model
    let alert: SettingsWidgetAlertsAlert
    @Binding var soundId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $soundId) {
                    ForEach(model.getAllAlertSounds()) { sound in
                        HStack {
                            Text(sound.name)
                            Spacer()
                            Button {
                                player = loadSound(model: model, soundId: sound.id)
                                player?.play()
                            } label: {
                                Image(systemName: "play.fill")
                            }
                        }
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
                NavigationLink {
                    SoundGalleryView(alert: alert, soundId: $soundId)
                } label: {
                    Text("My sounds")
                }
            }
        }
        .onDisappear {
            player = nil
        }
        .navigationTitle("Sound")
    }
}
