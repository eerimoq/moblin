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
            InlinePickerView(title: "Name",
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

private struct ScoreboardUndoButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdatePadelScoreboard(action: .init(id: widget.id, action: .undo))
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardIncrementHomeButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdatePadelScoreboard(action: .init(id: widget.id, action: .incrementHome))
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardIncrementAwayButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdatePadelScoreboard(action: .init(id: widget.id, action: .incrementAway))
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardResetScoreButtonView: View {
    let model: Model
    let widget: SettingsWidget
    @State private var presentingResetConfirimation = false

    var body: some View {
        Button {
            presentingResetConfirimation = true
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .tint(.red)
        .confirmationDialog("", isPresented: $presentingResetConfirimation) {
            Button("Reset score", role: .destructive) {
                model.handleUpdatePadelScoreboard(action: .init(id: widget.id, action: .reset))
            }
        }
    }
}

struct WidgetScoreboardPadelQuickButtonControlsView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 13) {
                Spacer()
                ScoreboardUndoButtonView(model: model, widget: widget)
                ScoreboardIncrementHomeButtonView(model: model, widget: widget)
            }
            HStack(spacing: 13) {
                Spacer()
                ScoreboardResetScoreButtonView(model: model, widget: widget)
                ScoreboardIncrementAwayButtonView(model: model, widget: widget)
            }
        }
        .font(.title)
    }
}

struct WidgetScoreboardPadelGeneralSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
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
        ScoreboardColorsView(model: model, widget: widget, scoreboard: scoreboard)
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
