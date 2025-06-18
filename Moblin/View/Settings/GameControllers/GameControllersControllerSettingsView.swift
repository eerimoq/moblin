import SwiftUI

struct GameControllersControllerSettingsView: View {
    @ObservedObject var gameController: SettingsGameController

    var body: some View {
        Form {
            Section {
                ForEach(gameController.buttons) { button in
                    GameControllersControllerButtonSettingsView(button: button)
                }
            }
        }
        .navigationTitle("Controller")
    }
}
