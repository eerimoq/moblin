import SwiftUI

struct GameControllersSettingsView: View {
    @ObservedObject var database: Database

    private func gameControllerIndex(gameController: SettingsGameController) -> Int {
        if let index = database.gameControllers.firstIndex(where: { gameController2 in
            gameController.id == gameController2.id
        }) {
            return index + 1
        } else {
            return 1
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Use game controllers to zoom, set scene, and more, from a distance.")
            }
            Section {
                List {
                    ForEach(database.gameControllers) { gameController in
                        NavigationLink {
                            GameControllersControllerSettingsView(gameController: gameController)
                        } label: {
                            Text("Controller \(gameControllerIndex(gameController: gameController))")
                        }
                    }
                    .onDelete { indexSet in
                        database.gameControllers.remove(atOffsets: indexSet)
                    }
                }
                CreateButtonView {
                    database.gameControllers.append(SettingsGameController())
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a controller"))
            }
        }
        .navigationTitle("Game controllers")
    }
}
