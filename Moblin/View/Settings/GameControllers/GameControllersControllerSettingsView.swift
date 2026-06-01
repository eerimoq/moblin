import SwiftUI

struct GameControllersControllerSettingsView: View {
    let model: Model
    @ObservedObject var gameController: SettingsGameController

    var body: some View {
        Form {
            Section("Buttons") {
                ForEach(gameController.buttons) { button in
                    GameControllersControllerButtonSettingsView(model: model, button: button)
                }
            }
            Section("Thumb sticks") {
                GameControllersControllerThumbStickSettingsView(
                    model: model,
                    image: "l.joystick",
                    name: "Left",
                    function: $gameController.leftThumbStickFunction
                )
                GameControllersControllerThumbStickSettingsView(
                    model: model,
                    image: "r.joystick",
                    name: "Right",
                    function: $gameController.rightThumbStickFunction
                )
            }
        }
        .navigationTitle("Controller")
    }
}
