import SwiftUI

private struct NicknameView: View {
    let model: Model
    @ObservedObject var nickname: SettingsChatNickname

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: "User", value: nickname.user) { value in
                        nickname.user = value
                        model.reloadChatMessages()
                    }
                    TextEditNavigationView(title: "Nickname", value: nickname.nickname) { value in
                        nickname.nickname = value
                        model.reloadChatMessages()
                    }
                }
                Section {
                    Button {
                        let username = nickname.nickname.isEmpty ? nickname.user : nickname.nickname
                        model.previewTextToSpeech(username: username, message: "This is a test message")
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                            Text("TTS Nickname")
                        }
                        .foregroundColor(.primary)
                    }
                    .disabled(nickname.user.isEmpty)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Nickname")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(nickname.user)
                Spacer()
                Text(nickname.nickname)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ChatNicknamesSettingsView: View {
    let model: Model
    @ObservedObject var nicknames: SettingsChatNicknames

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(nicknames.nicknames) { nickname in
                            NicknameView(model: model, nickname: nickname)
                        }
                        .onMove { froms, to in
                            nicknames.nicknames.move(fromOffsets: froms, toOffset: to)
                        }
                        .onDelete { offsets in
                            nicknames.nicknames.remove(atOffsets: offsets)
                            model.reloadChatMessages()
                        }
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
                Text(String(nicknames.nicknames.count))
                    .foregroundColor(.gray)
            }
        }
    }
}
