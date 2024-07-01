import SwiftUI

struct MediaPlayersSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
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
                        model.database.mediaPlayers!.players.remove(atOffsets: indexes)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    model.database.mediaPlayers!.players.append(SettingsMediaPlayer())
                    model.store()
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Media players")
        .toolbar {
            SettingsToolbar()
        }
    }
}
