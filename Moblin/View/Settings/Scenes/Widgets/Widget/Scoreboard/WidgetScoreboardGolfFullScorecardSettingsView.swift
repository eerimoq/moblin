import SwiftUI

struct WidgetScoreboardGolfFullScorecardGeneralSettingsView: View {
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    let updated: () -> Void

    var body: some View {
        ScoreboardColorsView(scoreboard: scoreboard, updated: updated)
    }
}

struct WidgetScoreboardGolfFullScorecardSettingsView: View {
    @ObservedObject var golf: SettingsWidgetGolfScoreboard
    let updated: () -> Void

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Title"), value: golf.title) {
                golf.title = $0
                updated()
            }
            Picker("Holes", selection: $golf.numberOfHoles) {
                ForEach([9, 18], id: \.self) {
                    Text(String($0))
                }
            }
            .onChange(of: golf.numberOfHoles) { _ in
                golf.currentHole = 0
                updated()
            }
            NavigationLink {
                Form {
                    ForEach(0 ..< golf.numberOfHoles, id: \.self) { i in
                        Picker("Hole \(i + 1)", selection: $golf.pars[i]) {
                            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) {
                                Text(String($0))
                            }
                        }
                        .onChange(of: golf.pars) { _ in
                            updated()
                        }
                    }
                }
                .navigationTitle("Pars")
            } label: {
                HStack {
                    Text("Par")
                    Spacer()
                    Text(String(golf.pars.prefix(golf.numberOfHoles).reduce(0, +)))
                        .foregroundStyle(.gray)
                }
            }
        } header: {
            Text("Round")
        }
        Section {
            List {
                ForEach(golf.players) { player in
                    TextEditNavigationView(title: String(localized: "Name"), value: player.name) {
                        player.name = $0
                        updated()
                    }
                    .contextMenuDeleteButton {
                        if let offsets = makeOffsets(golf.players, player.id) {
                            golf.players.remove(atOffsets: offsets)
                            updated()
                        }
                    }
                }
                .onDelete { offsets in
                    golf.players.remove(atOffsets: offsets)
                    updated()
                }
            }
            if golf.players.count < 4 {
                CreateButtonView {
                    let n = golf.players.count + 1
                    golf.players.append(SettingsWidgetGolfScoreboardPlayer(name: "Player \(n)"))
                    updated()
                }
            }
        } header: {
            Text("Players")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a player"))
        }
    }
}
