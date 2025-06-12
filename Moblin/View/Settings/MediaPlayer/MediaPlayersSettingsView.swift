import SwiftUI

struct MediaPlayersSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var mediaPlayers: SettingsMediaPlayers

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
                        MediaPlayerSettingsView(player: player)
                    }
                    .onDelete(perform: { indexes in
                        for index in indexes {
                            model.deleteMediaPlayer(playerId: mediaPlayers.players[index].id)
                        }
                        mediaPlayers.players.remove(atOffsets: indexes)
                    })
                }
                CreateButtonView {
                    let settings = SettingsMediaPlayer()
                    mediaPlayers.players.append(settings)
                    model.addMediaPlayer(settings: settings)
                }
            }
        }
        .navigationTitle("Media players")
    }
}
