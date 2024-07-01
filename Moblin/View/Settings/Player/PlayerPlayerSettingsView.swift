import SwiftUI

struct PlayerPlayerSettingsView: View {
    @EnvironmentObject var model: Model
    var player: SettingsPlayerPlayer

    private func submitName(value: String) {
        player.name = value.trim()
        model.store()
        model.objectWillChange.send()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: player.name,
                    onSubmit: submitName,
                    capitalize: true
                )
            }
            Section {
                Toggle("Auto select mic", isOn: Binding(get: {
                    player.autoSelectMic
                }, set: { value in
                    player.autoSelectMic = value
                    model.store()
                    model.objectWillChange.send()
                }))
            }
            Section {
                List {
                    ForEach(player.files) { file in
                        NavigationLink(destination: PlayerPlayerFileSettingsView(file: file)) {
                            HStack {
                                Text(file.name)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: { indexes in
                        player.files.remove(atOffsets: indexes)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    player.files.append(SettingsPlayerPlayerFile())
                    model.store()
                    model.objectWillChange.send()
                })
            } header: {
                Text("Files")
            }
        }
        .navigationTitle("Player")
        .toolbar {
            SettingsToolbar()
        }
    }
}
