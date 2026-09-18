import AVFAudio
import SwiftUI
import UniformTypeIdentifiers

@MainActor
private func loadSound(model: Model, soundId: UUID) -> AudioPlayer? {
    let url: URL? = if let bundledSound = model.database.alertsMediaGallery.bundledSounds
        .first(where: { $0.id == soundId })
    {
        Bundle.main.url(forResource: "Alerts.bundle/\(bundledSound.name)", withExtension: "mp3")
    } else {
        model.alertMediaStorage.makePath(id: soundId)
    }
    guard let url else {
        return nil
    }
    return try? AudioPlayer(contentsOf: url)
}

private struct CustomSoundView: View {
    @EnvironmentObject var model: Model
    let media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var audioPlayer: AudioPlayer?

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
    @ObservedObject var gallery: SettingsAlertsMediaGallery
    let alert: SettingsWidgetAlertsAlert
    @Binding var soundId: UUID

    private func deleteSound(at offsets: IndexSet) {
        gallery.customSounds.remove(atOffsets: offsets)
        model.fixAlertMedias()
        soundId = alert.soundId
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(gallery.customSounds) { sound in
                        NavigationLink {
                            CustomSoundView(
                                media: sound,
                                audioPlayer: loadSound(model: model, soundId: sound.id)
                            )
                        } label: {
                            Text(sound.name)
                        }
                        .contextMenuDeleteButton {
                            if let offsets = makeOffsets(gallery.customSounds, sound.id) {
                                deleteSound(at: offsets)
                            }
                        }
                    }
                    .onDelete(perform: deleteSound)
                }
                TextButtonView("Add") {
                    gallery.customSounds.append(SettingsAlertsMediaGalleryItem(name: "My sound"))
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a sound"))
            }
        }
        .navigationTitle("My sounds")
    }
}

@MainActor
private var player: AudioPlayer?

struct AlertSoundSelectorView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var gallery: SettingsAlertsMediaGallery
    let alert: SettingsWidgetAlertsAlert
    @Binding var soundId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $soundId) {
                    ForEach(gallery.bundledSounds + gallery.customSounds) { sound in
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
                    SoundGalleryView(gallery: gallery, alert: alert, soundId: $soundId)
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
