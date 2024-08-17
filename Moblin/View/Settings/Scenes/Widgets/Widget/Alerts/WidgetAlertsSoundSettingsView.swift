import AVFAudio
import SwiftUI
import UniformTypeIdentifiers

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
                Text("My sounds")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a sound"))
            }
        }
        .navigationTitle("Gallery")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct AlertSoundSelectorView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @Binding var soundId: UUID

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
