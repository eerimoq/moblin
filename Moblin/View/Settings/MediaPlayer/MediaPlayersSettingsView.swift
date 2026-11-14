import SwiftUI

struct MediaPlayersSettingsView: View {
    let model: Model
    @ObservedObject var mediaPlayers: SettingsMediaPlayers

    private func deletePlayer(at offsets: IndexSet) {
        let playerIds = offsets.map { mediaPlayers.players[$0].id }
        mediaPlayers.players.remove(atOffsets: offsets)
        for playerId in playerIds {
            model.deleteMediaPlayer(playerId: playerId)
        }
        model.updateMediaPlayerVideoSourcesAndMics()
    }

    var body: some View {
        Form {
            Section {
                Text("""
                Use a media player as video source in scenes and as mic to stream recordings \
                or other MP4-files.
                """)
            }
            Section {
                Text("⚠️ Audio is not yet fully supported, but might work.")
            }
            Section {
                List {
                    ForEach(mediaPlayers.players) { player in
                        MediaPlayerSettingsView(model: model, mediaPlayers: mediaPlayers, player: player)
                            .contextMenuDeleteButton {
                                if let offsets = makeOffsets(mediaPlayers.players, player.id) {
                                    deletePlayer(at: offsets)
                                }
                            }
                    }
                    .onDelete(perform: deletePlayer)
                }
                CreateButtonView {
                    let mediaPlayer = SettingsMediaPlayer()
                    mediaPlayer.name = makeUniqueName(name: SettingsMediaPlayer.baseName,
                                                      existingNames: mediaPlayers.players)
                    mediaPlayers.players.append(mediaPlayer)
                    model.addMediaPlayer(settings: mediaPlayer)
                    model.updateMediaPlayerVideoSourcesAndMics()
                }
            }
        }
        .navigationTitle("Media players")
    }
}
