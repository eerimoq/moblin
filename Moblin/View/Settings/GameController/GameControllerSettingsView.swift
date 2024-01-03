import SwiftUI

struct GameControllerSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                ForEach(model.database.gameController!.buttons) { button in
                    NavigationLink(destination: GameControllerButtonSettingsView(
                        button: button,
                        selection: button.function
                    )) {
                        HStack {
                            Image(systemName: button.name)
                            Spacer()
                            if button.function == .unused {
                                Text(button.function.toString())
                                    .foregroundColor(.gray)
                            } else {
                                Text(button.function.toString())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Game controller")
        .toolbar {
            SettingsToolbar()
        }
    }
}
