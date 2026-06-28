import SwiftUI

struct ControllerThumbStickView: View {
    @Binding var function: SettingsControllerThumbStickFunction

    var body: some View {
        Picker("Function", selection: $function) {
            Section {
                ForEach(SettingsControllerThumbStickFunction.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
        }
    }
}

struct GameControllersControllerThumbStickSettingsView: View {
    let image: String
    let name: LocalizedStringKey
    @Binding var function: SettingsControllerThumbStickFunction

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    ControllerThumbStickView(function: $function)
                }
            }
            .navigationTitle("Thumb stick")
        } label: {
            Label {
                HStack {
                    Text(name)
                    Spacer()
                    Text(function.toString())
                        .foregroundStyle(function.color())
                }
            } icon: {
                Image(systemName: image)
            }
        }
    }
}
