import SwiftUI

struct GameControllersControllerButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: SettingsGameControllerButton

    private func onFunctionChange(function: String) {
        button.function = SettingsGameControllerButtonFunction(rawValue: function) ?? .unused
    }

    private func buttonText() -> String {
        switch button.function {
        case .scene:
            return "\(model.getSceneName(id: button.sceneId)) scene"
        default:
            return button.function.toString()
        }
    }

    private func buttonColor() -> Color {
        switch button.function {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        InlinePickerView(
                            title: String(localized: "Function"),
                            onChange: onFunctionChange,
                            items: SettingsGameControllerButtonFunction.allCases.map { .init(
                                id: $0.rawValue,
                                text: $0.toString()
                            ) },
                            selectedId: button.function.rawValue
                        )
                    } label: {
                        TextItemView(name: String(localized: "Function"), value: button.function.toString())
                    }
                }
                if button.function == .scene {
                    Section {
                        Picker("", selection: $button.sceneId) {
                            ForEach(model.database.scenes) { scene in
                                Text(scene.name)
                                    .tag(scene.id)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("Scene")
                    }
                }
            }
            .navigationTitle("Game controller button")
        } label: {
            Label {
                HStack {
                    Text(button.text)
                    Spacer()
                    Text(buttonText())
                        .foregroundStyle(buttonColor())
                }
            } icon: {
                Image(systemName: button.name)
            }
        }
    }
}
