import SwiftUI

struct PlayerSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.player!.players) { player in
                        NavigationLink(destination: PlayerPlayerSettingsView(player: player)) {
                            HStack {
                                Text(player.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: { indexes in
                        model.database.player!.players.remove(atOffsets: indexes)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    model.database.player!.players.append(SettingsPlayerPlayer())
                    model.store()
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Players")
        .toolbar {
            SettingsToolbar()
        }
    }
}
