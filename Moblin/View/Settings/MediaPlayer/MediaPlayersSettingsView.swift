import SwiftUI

struct MediaPlayersSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var mediaPlayers: SettingsMediaPlayers

    private func deletePlayer(at offsets: IndexSet) {
        for index in offsets {
            model.deleteMediaPlayer(playerId: mediaPlayers.players[index].id)
        }
        mediaPlayers.players.remove(atOffsets: offsets)
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
                        MediaPlayerSettingsView(mediaPlayers: mediaPlayers, player: player)
                            .contextMenuDeleteButton {
                                if let index = mediaPlayers.players
                                    .firstIndex(where: { $0.id == player.id })
                                {
                                    deletePlayer(at: IndexSet(integer: index))
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
                }
            }
        }
        .navigationTitle("Media players")
    }
}
