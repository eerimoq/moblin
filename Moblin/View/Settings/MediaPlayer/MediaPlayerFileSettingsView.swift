import SwiftUI

struct MediaPlayerFileSettingsView: View {
    @EnvironmentObject var model: Model
    let player: SettingsMediaPlayer
    let file: SettingsMediaPlayerFile
    @State var image: UIImage?

    private func submitName(value: String) {
        file.name = value.trim()
        model.objectWillChange.send()
        model.updateMediaPlayerSettings(playerId: player.id, settings: player)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: file.name,
                        onSubmit: submitName,
                        capitalize: true
                    )
                }
            }
            .navigationTitle("File")
        } label: {
            HStack {
                DraggableItemPrefixView()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90)
                } else {
                    Image(systemName: "photo")
                }
                Text(file.name)
            }
        }
        .onAppear {
            createThumbnail(path: model.mediaStorage.makePath(id: file.id)) { image in
                self.image = image
            }
        }
    }
}
