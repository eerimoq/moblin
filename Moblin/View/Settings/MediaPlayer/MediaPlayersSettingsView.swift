import SwiftUI

struct MediaPlayersSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Text("""
                Use a media player as video source in scenes to stream recordings \
                or other MP4-files.
                """)
            }
            Section {
                Text("⚠️ Audio is not yet implemented.")
            }
            Section {
                List {
                    ForEach(model.database.mediaPlayers!.players) { player in
                        NavigationLink(destination: MediaPlayerSettingsView(player: player)) {
                            HStack {
                                Text(player.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: { indexes in
                        for index in indexes {
                            model.deleteMediaPlayer(playerId: model.database.mediaPlayers!.players[index].id)
                        }
                        model.database.mediaPlayers!.players.remove(atOffsets: indexes)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    let settings = SettingsMediaPlayer()
                    model.database.mediaPlayers!.players.append(settings)
                    model.store()
                    model.objectWillChange.send()
                    model.addMediaPlayer(settings: settings)
                })
            }
        }
        .navigationTitle("Media players")
        .toolbar {
            SettingsToolbar()
        }
    }
}
