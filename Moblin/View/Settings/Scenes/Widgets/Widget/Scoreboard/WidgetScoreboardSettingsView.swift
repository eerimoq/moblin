import SwiftUI

private struct PlayersView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            List {
                ForEach(model.database.scoreboardPlayers!) { player in
                    Text(player.name)
                }
                .onMove(perform: { froms, to in
                    model.database.scoreboardPlayers!.move(fromOffsets: froms, toOffset: to)
                })
                .onDelete(perform: { offsets in
                    model.database.scoreboardPlayers!.remove(atOffsets: offsets)
                })
            }
            CreateButtonView(action: {
                model.database.scoreboardPlayers!.append(.init())
            })
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a player"))
        }
    }
}

struct WidgetScoreboardSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var type: String

    var body: some View {
        PlayersView()
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
                }
            }
        }
    }
}
