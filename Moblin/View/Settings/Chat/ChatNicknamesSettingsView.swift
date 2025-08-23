import SwiftUI

struct ChatNicknamesSettingsView: View {
    @ObservedObject var chat: SettingsChat
    @ObservedObject var model: Model
    @State private var showingAddNickname = false
    @State private var editingUsername: String?
    @State private var editingNickname = ""

    var sortedNicknames: [(String, String)] {
        chat.nicknames.sorted { $0.value.lowercased() < $1.value.lowercased() }
    }

    var body: some View {
        Form {
            if chat.nicknames.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No nicknames set")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("Use the context menu on chat messages to set nicknames")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } footer: {
                    Text("Long press on any chat message and tap 'Nickname' to set a custom display name for users.")
                }
            } else {
                Section {
                    ForEach(sortedNicknames, id: \.0) { username, nickname in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nickname)
                                    .font(.headline)
                                Text("Username: \(username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                editNickname(username: username, currentNickname: nickname)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                deleteNickname(username: username)
                            }
                        }
                    }
                } header: {
                    Text("Nicknames (\(chat.nicknames.count))")
                } footer: {
                    Text("Swipe left to delete nicknames. Use the context menu on chat messages to add new ones.")
                }
            }
        }
        .navigationTitle("Chat Nicknames")
        .alert("Edit Nickname", isPresented: .constant(editingUsername != nil)) {
            TextField("Nickname", text: $editingNickname)
            Button("Save") {
                saveEditedNickname()
            }
            .disabled(editingNickname.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Delete", role: .destructive) {
                if let username = editingUsername {
                    deleteNickname(username: username)
                }
                editingUsername = nil
            }
            Button("Cancel", role: .cancel) {
                editingUsername = nil
            }
        } message: {
            if let username = editingUsername {
                Text("Edit nickname for user: \(username)")
            }
        }
    }

    private func editNickname(username: String, currentNickname: String) {
        editingUsername = username
        editingNickname = currentNickname
    }

    private func saveEditedNickname() {
        guard let username = editingUsername else { return }

        let trimmed = editingNickname.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            chat.nicknames[username] = trimmed
            model.reloadChatMessages()
        }
        editingUsername = nil
    }

    private func deleteNickname(username: String) {
        chat.nicknames.removeValue(forKey: username)
        model.reloadChatMessages()
        editingUsername = nil
    }
}
