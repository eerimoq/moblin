import PhotosUI
import SwiftUI

struct Video: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let fileName = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return .init(url: copy)
        }
    }
}

struct MediaPlayerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var player: SettingsMediaPlayer
    @State var selectedVideoItem: PhotosPickerItem?

    private func submitName(value: String) {
        player.name = value.trim()
        model.updateMediaPlayerSettings(playerId: player.id, settings: player)
    }

    private func appendMedia(url: URL) {
        let file = SettingsMediaPlayerFile()
        model.mediaStorage.add(id: file.id, url: url)
        player.playlist.append(file)
        model.updateMediaPlayerSettings(playerId: player.id, settings: player)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: player.name,
                        onSubmit: submitName,
                        capitalize: true
                    )
                }
                if false {
                    Section {
                        Toggle("Auto select mic", isOn: $player.autoSelectMic)
                    }
                }
                Section {
                    List {
                        ForEach(player.playlist) { file in
                            NavigationLink {
                                MediaPlayerFileSettingsView(player: player, file: file)
                            } label: {
                                HStack {
                                    DraggableItemPrefixView()
                                    if let image = createThumbnail(path: model.mediaStorage.makePath(id: file.id)) {
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
                        }
                        .onMove(perform: { froms, to in
                            player.playlist.move(fromOffsets: froms, toOffset: to)
                            model.updateMediaPlayerSettings(playerId: player.id, settings: player)
                        })
                        .onDelete(perform: { indexes in
                            player.playlist.remove(atOffsets: indexes)
                            model.updateMediaPlayerSettings(playerId: player.id, settings: player)
                        })
                    }
                    PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                        HCenter {
                            Text("Add")
                        }
                    }
                    .onChange(of: selectedVideoItem) { videoItem in
                        selectedVideoItem = nil
                        videoItem?.loadTransferable(type: Video.self) { result in
                            switch result {
                            case let .success(video?):
                                DispatchQueue.main.async {
                                    self.appendMedia(url: video.url)
                                }
                            case .success(nil):
                                logger.error("media-player: Media is nil")
                            case let .failure(error):
                                logger.error("media-player: Media error: \(error)")
                            }
                        }
                    }
                } header: {
                    Text("Playlist")
                }
            }
            .navigationTitle("Media player")
        } label: {
            HStack {
                Text(player.name)
                Spacer()
            }
        }
    }
}
