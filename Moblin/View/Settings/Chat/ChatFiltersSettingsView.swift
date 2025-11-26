import SwiftUI

private struct UsernameEditView: View {
    @State var value: String
    let onSubmit: (String) -> Void
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

private struct ChatFilterFilterSettingsView: View {
    @ObservedObject var filter: SettingsChatFilter

    var body: some View {
        Section {
            NavigationLink {
                TextEditView(
                    title: String(localized: "Username"),
                    value: filter.user,
                    onSubmit: {
                        filter.user = $0
                    }
                )
            } label: {
                TextItemView(name: String(localized: "Username"), value: filter.username())
            }
            NavigationLink {
                TextEditView(
                    title: String(localized: "Message starts with"),
                    value: filter.messageStart,
                    onSubmit: {
                        if $0.isEmpty {
                            filter.messageStartWords = []
                        } else {
                            filter.messageStartWords = $0.components(separatedBy: " ")
                        }
                        filter.messageStart = filter.messageStartWords.joined(separator: " ")
                    }
                )
            } label: {
                TextItemView(name: String(localized: "Message starts with"), value: filter.message())
            }
        } header: {
            Text("Condition")
        } footer: {
            Text("""
            The condition is true when both "Username" and "Message starts with" matches the received \
            chat message.
            """)
        }
    }
}

private struct ChatFilterActionsSettingsView: View {
    @ObservedObject var filter: SettingsChatFilter

    var body: some View {
        Section {
            Toggle(isOn: $filter.showOnScreen) {
                Text("Show on screen")
            }
            Toggle(isOn: $filter.textToSpeech) {
                Text("Text to speech")
            }
            Toggle(isOn: $filter.chatBot) {
                Text("Chat bot")
            }
            Toggle(isOn: $filter.poll) {
                Text("Poll")
            }
            Toggle(isOn: $filter.print) {
                Text("Print")
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("The actions to perform when the condition is true.")
        }
    }
}

private struct ChatFilterSettingsView: View {
    @ObservedObject var filter: SettingsChatFilter

    var body: some View {
        NavigationLink {
            Form {
                ChatFilterFilterSettingsView(filter: filter)
                ChatFilterActionsSettingsView(filter: filter)
            }
            .navigationTitle("Filter")
        } label: {
            HStack {
                DraggableItemPrefixView()
                TextItemView(
                    name: String(localized: "Username"),
                    value: filter.username()
                )
            }
        }
    }
}

struct ChatFiltersSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(chat.filters) { filter in
                            ChatFilterSettingsView(filter: filter)
                        }
                        .onMove { froms, to in
                            chat.filters.move(fromOffsets: froms, toOffset: to)
                        }
                        .onDelete { offsets in
                            chat.filters.remove(atOffsets: offsets)
                        }
                    }
                    AddButtonView(action: {
                        chat.filters.append(SettingsChatFilter())
                    })
                } footer: {
                    VStack(alignment: .leading) {
                        Text("The first filter that matches is used.")
                        Text("")
                        SwipeLeftToRemoveHelpView(kind: String(localized: "a filter"))
                    }
                }
            }
            .navigationTitle("Filters")
        } label: {
            HStack {
                Text("Filters")
                Spacer()
                Text(String(chat.filters.count))
                    .foregroundStyle(.gray)
            }
        }
    }
}
