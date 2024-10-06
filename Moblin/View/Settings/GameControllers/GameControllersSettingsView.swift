import SwiftUI

struct GameControllersSettingsView: View {
    @EnvironmentObject var model: Model

    private func gameControllerIndex(gameController: SettingsGameController) -> Int {
        if let index = model.database.gameControllers!.firstIndex(where: { gameController2 in
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
                    ForEach(model.database.gameControllers!) { gameController in
                        NavigationLink {
                            GameControllersControllerSettingsView(gameController: gameController)
                        } label: {
                            Text("Controller \(gameControllerIndex(gameController: gameController))")
                        }
                    }
                    .onDelete(perform: { indexSet in
                        model.database.gameControllers?.remove(atOffsets: indexSet)
                    })
                }
                CreateButtonView {
                    model.database.gameControllers?.append(SettingsGameController())
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a controller"))
            }
        }
        .navigationTitle("Game controllers")
    }
}
