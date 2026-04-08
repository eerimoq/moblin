import SwiftUI

private struct NicknameView: View {
    let model: Model
    @ObservedObject var nickname: SettingsChatNickname

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: "User",
                                           value: nickname.user,
                                           onSubmit: { value in
                                               nickname.user = value
                                               model.reloadChatMessages()
                                           })
                    TextEditNavigationView(title: "Nickname",
                                           value: nickname.nickname,
                                           onSubmit: { value in
                                               nickname.nickname = value
                                               model.reloadChatMessages()
                                           })
                }
                Section {
                    TextButtonView("Test") {
                        model.previewTextToSpeech(
                            username: nickname.nickname,
                            message: "This is a test message"
                        )
                    }
                    .disabled(nickname.nickname.isEmpty)
                }
            }
            .navigationTitle("Nickname")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(nickname.user)
                Spacer()
                GrayTextView(text: nickname.nickname)
            }
        }
    }
}

struct ChatNicknamesSettingsView: View {
    let model: Model
    @ObservedObject var nicknames: SettingsChatNicknames

    private func deleteNickname(at offsets: IndexSet) {
        nicknames.nicknames.remove(atOffsets: offsets)
        model.reloadChatMessages()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(nicknames.nicknames) { nickname in
                            NicknameView(model: model, nickname: nickname)
                                .contextMenuDeleteButton {
                                    if let index = nicknames.nicknames
                                        .firstIndex(where: { $0.id == nickname.id })
                                    {
                                        deleteNickname(at: IndexSet(integer: index))
                                    }
                                }
                        }
                        .onMove { froms, to in
                            nicknames.nicknames.move(fromOffsets: froms, toOffset: to)
                        }
                        .onDelete(perform: deleteNickname)
                    }
                    CreateButtonView {
                        nicknames.nicknames.append(SettingsChatNickname())
                    }
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a nickname"))
                }
            }
            .navigationTitle("Nicknames")
        } label: {
            HStack {
                Text("Nicknames")
                Spacer()
                GrayTextView(text: String(nicknames.nicknames.count))
            }
        }
    }
}
