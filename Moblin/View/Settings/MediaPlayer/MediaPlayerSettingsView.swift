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
    @ObservedObject var mediaPlayers: SettingsMediaPlayers
    @ObservedObject var player: SettingsMediaPlayer
    @State var selectedVideoItem: PhotosPickerItem?

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
                    NameEditView(name: $player.name, existingNames: mediaPlayers.players)
                        .onChange(of: player.name) { _ in
                            model.updateMediaPlayerSettings(playerId: player.id, settings: player)
                        }
                }
                if false {
                    Section {
                        Toggle("Auto select mic", isOn: $player.autoSelectMic)
                    }
                }
                Section {
                    List {
                        ForEach(player.playlist) { file in
                            MediaPlayerFileSettingsView(player: player, file: file)
                        }
                        .onMove { froms, to in
                            player.playlist.move(fromOffsets: froms, toOffset: to)
                            model.updateMediaPlayerSettings(playerId: player.id, settings: player)
                        }
                        .onDelete { indexes in
                            player.playlist.remove(atOffsets: indexes)
                            model.updateMediaPlayerSettings(playerId: player.id, settings: player)
                        }
                    }
                    PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                        HCenter {
                            if selectedVideoItem != nil {
                                ProgressView()
                            } else {
                                Text("Add")
                            }
                        }
                    }
                    .disabled(selectedVideoItem != nil)
                    .onChange(of: selectedVideoItem) { videoItem in
                        videoItem?.loadTransferable(type: Video.self) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case let .success(video?):
                                    self.appendMedia(url: video.url)
                                case .success(nil):
                                    logger.error("media-player: Media is nil")
                                case let .failure(error):
                                    logger.error("media-player: Media error: \(error)")
                                }
                                selectedVideoItem = nil
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
