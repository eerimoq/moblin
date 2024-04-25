import SwiftUI

private struct UsernameEditView: View {
    @State var value: String
    var onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false

    private func submit() {
        submitted = true
        value = value.trim()
        onSubmit(value)
    }

    var body: some View {
        TextField("", text: $value)
            .keyboardType(.default)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .onChange(of: value) { _ in
                changed = true
            }
            .onSubmit {
                submit()
            }
            .submitLabel(.done)
            .onDisappear {
                if changed && !submitted {
                    submit()
                }
            }
    }
}

struct ChatUsernamesToIgnoreSettingsView: View {
    @EnvironmentObject var model: Model

    private func onSubmit(_ username: SettingsChatUsername, _ value: String) {
        username.value = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.chat.usernamesToIgnore!) { username in
                        UsernameEditView(value: username.value, onSubmit: { value in onSubmit(username, value) })
                    }
                    .onMove(perform: { froms, to in
                        model.database.chat.usernamesToIgnore!.move(fromOffsets: froms, toOffset: to)
                        model.store()
                    })
                    .onDelete(perform: { offsets in
                        model.database.chat.usernamesToIgnore!.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                AddButtonView(action: {
                    model.database.chat.usernamesToIgnore!.append(SettingsChatUsername())
                    model.store()
                })
            } footer: {
                SwipeLeftToRemoveHelpView(kind: String(localized: "a username"))
            }
        }
        .navigationTitle("Usernames to ignore")
        .toolbar {
            SettingsToolbar()
        }
    }
}
