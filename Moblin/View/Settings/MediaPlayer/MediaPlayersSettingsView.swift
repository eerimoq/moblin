import SwiftUI

struct MediaPlayersSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

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
                    ForEach(database.mediaPlayers.players) { player in
                        NavigationLink {
                            MediaPlayerSettingsView(player: player)
                        } label: {
                            HStack {
                                Text(player.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: { indexes in
                        for index in indexes {
                            model.deleteMediaPlayer(playerId: database.mediaPlayers.players[index].id)
                        }
                        database.mediaPlayers.players.remove(atOffsets: indexes)
                    })
                }
                CreateButtonView {
                    let settings = SettingsMediaPlayer()
                    database.mediaPlayers.players.append(settings)
                    model.objectWillChange.send()
                    model.addMediaPlayer(settings: settings)
                }
            }
        }
        .navigationTitle("Media players")
    }
}
