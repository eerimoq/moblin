import SwiftUI

private struct PlayersView: View {
    @EnvironmentObject var model: Model

    private func submitName(player: SettingsWidgetScoreboardPlayer, value: String) {
        player.name = value
    }

    var body: some View {
        Section {
            List {
                ForEach(model.database.scoreboardPlayers!) { player in
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Name"),
                            value: player.name,
                            onSubmit: {
                                submitName(player: player, value: $0)
                                model.resetSelectedScene(changeScene: false)
                            }
                        )
                    } label: {
                        Text(player.name)
                    }
                }
                .onMove(perform: { froms, to in
                    model.database.scoreboardPlayers!.move(fromOffsets: froms, toOffset: to)
                    model.resetSelectedScene(changeScene: false)
                })
                .onDelete(perform: { offsets in
                    model.database.scoreboardPlayers!.remove(atOffsets: offsets)
                    model.resetSelectedScene(changeScene: false)
                })
            }
            CreateButtonView(action: {
                model.database.scoreboardPlayers!.append(.init())
                model.objectWillChange.send()
            })
        } header: {
            Text("Players")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a player"))
        }
    }
}

struct WidgetScoreboardSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var type: String
    @State var gameType: String

    var body: some View {
        Section {
            HStack {
                Text("Type")
                Spacer()
                Picker("", selection: $type) {
                    ForEach(scoreboardTypes, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: type) {
                    widget.scoreboard!.type = SettingsWidgetScoreboardType.fromString(value: $0)
                    model.resetSelectedScene(changeScene: false)
                }
            }
            HStack {
                Text("Game type")
                Spacer()
                Picker("", selection: $gameType) {
                    ForEach(scoreboardGameTypes, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: gameType) {
                    widget.scoreboard!.padel.type = SettingsWidgetPadelScoreboardGameType
                        .fromString(value: $0)
                    model.resetSelectedScene(changeScene: false)
                }
            }
        } header: {
            Text("General")
        }
        Section {
            NavigationLink {
                InlinePickerView(title: String(localized: "Name"),
                                 onChange: { value in
                                     widget.scoreboard!.padel
                                         .homePlayer1 = UUID(uuidString: value) ?? .init()
                                     model.resetSelectedScene(changeScene: false)
                                 },
                                 items: model.database.scoreboardPlayers!.map { .init(
                                     id: $0.id.uuidString, text: $0.name
                                 ) },
                                 selectedId: widget.scoreboard!.padel.homePlayer1.uuidString)
            } label: {
                Text(model.findScoreboardPlayer(id: widget.scoreboard!.padel.homePlayer1))
            }
            if SettingsWidgetPadelScoreboardGameType.fromString(value: gameType) == .double {
                NavigationLink {
                    InlinePickerView(title: String(localized: "Name"),
                                     onChange: { value in
                                         widget.scoreboard!.padel
                                             .homePlayer2 = UUID(uuidString: value) ?? .init()
                                         model.resetSelectedScene(changeScene: false)
                                     },
                                     items: model.database.scoreboardPlayers!.map { .init(
                                         id: $0.id.uuidString, text: $0.name
                                     ) },
                                     selectedId: widget.scoreboard!.padel.homePlayer2.uuidString)
                } label: {
                    Text(model.findScoreboardPlayer(id: widget.scoreboard!.padel.homePlayer2))
                }
            }
        } header: {
            Text("Home")
        }
        Section {
            NavigationLink {
                InlinePickerView(title: String(localized: "Name"),
                                 onChange: { value in
                                     widget.scoreboard!.padel
                                         .awayPlayer1 = UUID(uuidString: value) ?? .init()
                                     model.resetSelectedScene(changeScene: false)
                                 },
                                 items: model.database.scoreboardPlayers!.map { .init(
                                     id: $0.id.uuidString, text: $0.name
                                 ) },
                                 selectedId: widget.scoreboard!.padel.awayPlayer1.uuidString)
            } label: {
                Text(model.findScoreboardPlayer(id: widget.scoreboard!.padel.awayPlayer1))
            }
            if SettingsWidgetPadelScoreboardGameType.fromString(value: gameType) == .double {
                NavigationLink {
                    InlinePickerView(title: String(localized: "Name"),
                                     onChange: { value in
                                         widget.scoreboard!.padel
                                             .awayPlayer2 = UUID(uuidString: value) ?? .init()
                                         model.resetSelectedScene(changeScene: false)
                                     },
                                     items: model.database.scoreboardPlayers!.map { .init(
                                         id: $0.id.uuidString, text: $0.name
                                     ) },
                                     selectedId: widget.scoreboard!.padel.awayPlayer2.uuidString)
                } label: {
                    Text(model.findScoreboardPlayer(id: widget.scoreboard!.padel.awayPlayer2))
                }
            }
        } header: {
            Text("Away")
        }
        PlayersView()
    }
}
