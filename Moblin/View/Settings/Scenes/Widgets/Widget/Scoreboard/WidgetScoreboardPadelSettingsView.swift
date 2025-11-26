import SwiftUI

private struct PlayersPlayerView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var player: SettingsWidgetScoreboardPlayer

    var body: some View {
        NameEditView(name: $player.name, existingNames: database.scoreboardPlayers)
            .onChange(of: player.name) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
                model.sendScoreboardPlayersToWatch()
            }
    }
}

private struct PlayersView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            List {
                ForEach(database.scoreboardPlayers) { player in
                    PlayersPlayerView(model: model, database: database, player: player)
                }
                .onMove { froms, to in
                    database.scoreboardPlayers.move(fromOffsets: froms, toOffset: to)
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                    model.sendScoreboardPlayersToWatch()
                }
                .onDelete { offsets in
                    database.scoreboardPlayers.remove(atOffsets: offsets)
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                    model.sendScoreboardPlayersToWatch()
                }
            }
            CreateButtonView {
                let player = SettingsWidgetScoreboardPlayer()
                player.name = makeUniqueName(name: SettingsWidgetScoreboardPlayer.baseName,
                                             existingNames: database.scoreboardPlayers)
                database.scoreboardPlayers.append(player)
                model.sendScoreboardPlayersToWatch()
            }
        } header: {
            Text("Players")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a player"))
        }
    }
}

private struct PlayerView: View {
    @EnvironmentObject var model: Model
    @Binding var playerId: UUID

    var body: some View {
        NavigationLink {
            InlinePickerView(title: String(localized: "Name"),
                             onChange: {
                                 playerId = UUID(uuidString: $0) ?? .init()
                             },
                             items: model.database.scoreboardPlayers.map { .init(
                                 id: $0.id.uuidString, text: $0.name
                             ) },
                             selectedId: playerId.uuidString)
        } label: {
            Text(model.findScoreboardPlayer(id: playerId))
        }
    }
}

struct WidgetScoreboardPadelGeneralSettingsView: View {
    let model: Model
    @ObservedObject var padel: SettingsWidgetPadelScoreboard

    var body: some View {
        HStack {
            Text("Game type")
            Spacer()
            Picker("", selection: $padel.type) {
                ForEach(SettingsWidgetPadelScoreboardGameType.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: padel.type) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        }
    }
}

struct WidgetScoreboardPadelSettingsView: View {
    let model: Model
    @ObservedObject var padel: SettingsWidgetPadelScoreboard

    var body: some View {
        Section {
            PlayerView(playerId: $padel.homePlayer1)
                .onChange(of: padel.homePlayer1) { _ in
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                }
            if padel.type == .doubles {
                PlayerView(playerId: $padel.homePlayer2)
                    .onChange(of: padel.homePlayer2) { _ in
                        model.resetSelectedScene(changeScene: false, attachCamera: false)
                    }
            }
        } header: {
            Text("Home")
        }
        Section {
            PlayerView(playerId: $padel.awayPlayer1)
                .onChange(of: padel.awayPlayer1) { _ in
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                }
            if padel.type == .doubles {
                PlayerView(playerId: $padel.awayPlayer2)
                    .onChange(of: padel.awayPlayer2) { _ in
                        model.resetSelectedScene(changeScene: false, attachCamera: false)
                    }
            }
        } header: {
            Text("Away")
        }
        PlayersView(database: model.database)
    }
}
