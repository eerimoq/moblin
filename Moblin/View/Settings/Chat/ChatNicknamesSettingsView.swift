import SwiftUI

struct ChatNicknamesSettingsView: View {
    @ObservedObject var chat: SettingsChat
    @ObservedObject var model: Model
    @State private var showingAddNickname = false
    @State private var editingUserId: String?
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
                    ForEach(sortedNicknames, id: \.0) { userId, nickname in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nickname)
                                    .font(.headline)
                                Text("User ID: \(userId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                editNickname(userId: userId, currentNickname: nickname)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                deleteNickname(userId: userId)
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
        .alert("Edit Nickname", isPresented: .constant(editingUserId != nil)) {
            TextField("Nickname", text: $editingNickname)
            Button("Save") {
                saveEditedNickname()
            }
            .disabled(editingNickname.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Delete", role: .destructive) {
                if let userId = editingUserId {
                    deleteNickname(userId: userId)
                }
                editingUserId = nil
            }
            Button("Cancel", role: .cancel) {
                editingUserId = nil
            }
        } message: {
            if let userId = editingUserId {
                Text("Edit nickname for user: \(userId)")
            }
        }
    }

    private func editNickname(userId: String, currentNickname: String) {
        editingUserId = userId
        editingNickname = currentNickname
    }

    private func saveEditedNickname() {
        guard let userId = editingUserId else { return }

        let trimmed = editingNickname.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            chat.nicknames[userId] = trimmed
            model.reloadChatMessages()
        }
        editingUserId = nil
    }

    private func deleteNickname(userId: String) {
        chat.nicknames.removeValue(forKey: userId)
        model.reloadChatMessages()
        editingUserId = nil
    }
}
