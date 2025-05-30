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

    private func onSubmit(_ username: SettingsChatFilter, _ user: String) {
        username.user = user
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.chat.filters) { filter in
                        UsernameEditView(
                            value: filter.user,
                            onSubmit: { user in onSubmit(filter, user) }
                        )
                    }
                    .onMove(perform: { froms, to in
                        model.database.chat.filters.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        model.database.chat.filters.remove(atOffsets: offsets)
                    })
                }
                AddButtonView(action: {
                    model.database.chat.filters.append(SettingsChatFilter())
                    model.objectWillChange.send()
                })
            } footer: {
                SwipeLeftToRemoveHelpView(kind: String(localized: "a username"))
            }
        }
        .navigationTitle("Usernames to ignore")
    }
}
