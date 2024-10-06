import SwiftUI

struct GameControllersControllerSettingsView: View {
    @EnvironmentObject var model: Model
    var gameController: SettingsGameController

    private func buttonText(button: SettingsGameControllerButton) -> String {
        switch button.function {
        case .scene:
            return "\(model.getSceneName(id: button.sceneId)) scene"
        default:
            return button.function.toString()
        }
    }

    private func buttonColor(button: SettingsGameControllerButton) -> Color {
        switch button.function {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }

    var body: some View {
        Form {
            Section {
                ForEach(gameController.buttons) { button in
                    NavigationLink {
                        GameControllersControllerButtonSettingsView(
                            button: button,
                            selection: button.function.toString(),
                            sceneSelection: button.sceneId
                        )
                    } label: {
                        HStack {
                            Image(systemName: button.name)
                            Text(button.text!)
                            Spacer()
                            Text(buttonText(button: button))
                                .foregroundColor(buttonColor(button: button))
                        }
                    }
                }
            }
        }
        .navigationTitle("Controller")
    }
}
