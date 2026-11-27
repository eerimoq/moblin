import SwiftUI

private struct SoundView: View {
    let model: Model
    @ObservedObject var sound: SettingsAlertsMediaGalleryItem

    var body: some View {
        Button {
            model.playSoundBoardSound(soundId: sound.id)
        } label: {
            Text(sound.name)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}

struct QuickButtonSoundBoardView: View {
    let model: Model
    @ObservedObject var gallery: SettingsAlertsMediaGallery

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach(gallery.allSounds()) { sound in
                        SoundView(model: model, sound: sound)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ShortcutSectionView {
                NavigationLink {
                    SoundGalleryView(gallery: gallery) {}
                } label: {
                    Label("My sounds", systemImage: "speaker.wave.2")
                }
            }
        }
        .navigationTitle("Sound board")
    }
}
