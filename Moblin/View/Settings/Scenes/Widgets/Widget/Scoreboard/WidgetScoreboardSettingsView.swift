import SwiftUI

private struct PlayersView: View {
    @EnvironmentObject var model: Model

    private func submitName(player: SettingsWidgetScoreboardPlayer, value: String) {
        player.name = value
    }

    var body: some View {
        Section {
            List {
                ForEach(model.database.scoreboardPlayers) { player in
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Name"),
                            value: player.name,
                            onSubmit: {
                                submitName(player: player, value: $0)
                                model.resetSelectedScene(changeScene: false)
                                model.sendScoreboardPlayersToWatch()
                            }
                        )
                    } label: {
                        Text(player.name)
                    }
                }
                .onMove(perform: { froms, to in
                    model.database.scoreboardPlayers.move(fromOffsets: froms, toOffset: to)
                    model.resetSelectedScene(changeScene: false)
                    model.sendScoreboardPlayersToWatch()
                })
                .onDelete(perform: { offsets in
                    model.database.scoreboardPlayers.remove(atOffsets: offsets)
                    model.resetSelectedScene(changeScene: false)
                    model.sendScoreboardPlayersToWatch()
                })
            }
            CreateButtonView {
                model.database.scoreboardPlayers.append(.init())
                model.sendScoreboardPlayersToWatch()
                model.objectWillChange.send()
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

struct WidgetScoreboardSettingsView: View {
    @EnvironmentObject var model: Model
    private var widget: SettingsWidget
    @State private var type: SettingsWidgetScoreboardType
    @State private var gameType: SettingsWidgetPadelScoreboardGameType
    @State private var homePlayer1: UUID
    @State private var homePlayer2: UUID
    @State private var awayPlayer1: UUID
    @State private var awayPlayer2: UUID

    init(widget: SettingsWidget, type: SettingsWidgetScoreboardType) {
        self.widget = widget
        self.type = type
        let padel = widget.scoreboard.padel
        gameType = padel.type
        homePlayer1 = padel.homePlayer1
        homePlayer2 = padel.homePlayer2
        awayPlayer1 = padel.awayPlayer1
        awayPlayer2 = padel.awayPlayer2
    }

    var body: some View {
        Section {
            HStack {
                Text("Type")
                Spacer()
                Picker("", selection: $type) {
                    ForEach(SettingsWidgetScoreboardType.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: type) {
                    widget.scoreboard.type = $0
                    model.resetSelectedScene(changeScene: false)
                }
            }
            HStack {
                Text("Game type")
                Spacer()
                Picker("", selection: $gameType) {
                    ForEach(SettingsWidgetPadelScoreboardGameType.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: gameType) {
                    widget.scoreboard.padel.type = $0
                    model.resetSelectedScene(changeScene: false)
                }
            }
        } header: {
            Text("General")
        }
        Section {
            PlayerView(playerId: $homePlayer1)
                .onChange(of: homePlayer1) { _ in
                    widget.scoreboard.padel.homePlayer1 = homePlayer1
                    model.resetSelectedScene(changeScene: false)
                }
            if gameType == .doubles {
                PlayerView(playerId: $homePlayer2)
                    .onChange(of: homePlayer2) { _ in
                        widget.scoreboard.padel.homePlayer2 = homePlayer2
                        model.resetSelectedScene(changeScene: false)
                    }
            }
        } header: {
            Text("Home")
        }
        Section {
            PlayerView(playerId: $awayPlayer1)
                .onChange(of: awayPlayer1) { _ in
                    widget.scoreboard.padel.awayPlayer1 = awayPlayer1
                    model.resetSelectedScene(changeScene: false)
                }
            if gameType == .doubles {
                PlayerView(playerId: $awayPlayer2)
                    .onChange(of: awayPlayer2) { _ in
                        widget.scoreboard.padel.awayPlayer2 = awayPlayer2
                        model.resetSelectedScene(changeScene: false)
                    }
            }
        } header: {
            Text("Away")
        }
        PlayersView()
    }
}
