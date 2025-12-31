import SwiftUI

struct GameControllersControllerSettingsView: View {
    let model: Model
    @ObservedObject var gameController: SettingsGameController

    var body: some View {
        Form {
            Section {
                ForEach(gameController.buttons) { button in
                    GameControllersControllerButtonSettingsView(model: model, button: button)
                }
            }
        }
        .navigationTitle("Controller")
    }
}
