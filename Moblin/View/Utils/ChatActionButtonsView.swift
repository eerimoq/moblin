import SwiftUI

private struct ActionButtonView: View {
    var image: String
    var text: LocalizedStringKey
    var foreground: Color?
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack {
                if let foreground {
                    Image(systemName: image)
                        .foregroundStyle(foreground)
                        .font(.title2)
                } else {
                    Image(systemName: image)
                        .font(.title2)
                }
                Text(text)
                    .foregroundStyle(.white)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
}

struct ChatActionButtonsView: View {
    let model: Model
    let style: ChatLineStyle
    @Binding var selectedPost: ChatPost?
    @Binding var linkUrl: URL?
    @State private var presentingBanConfirm = false
    @State private var presentingTimeoutConfirm = false
    @State private var presentingDeleteConfirm = false
    @State private var presentingNicknameDialog = false
    @State private var nicknameText = ""
    @State private var showingChatterInfo = false

    private func dismiss() {
        showingChatterInfo = false
        selectedPost = nil
    }

    private var chat: SettingsChat {
        model.database.chat
    }

    private func banButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "nosign", text: "Ban", foreground: .red) {
            presentingBanConfirm = true
        }
        .confirmationDialog("", isPresented: $presentingBanConfirm) {
            Button("Ban", role: .destructive) {
                model.banUser(post: selectedPost)
                dismiss()
            }
        }
    }

    private func timeoutButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "timer", text: "Timeout") {
            presentingTimeoutConfirm = true
        }
        .confirmationDialog("", isPresented: $presentingTimeoutConfirm) {
            Button("5 minutes timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 5 * 60)
                dismiss()
            }
            Button("1 hour timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 3600)
                dismiss()
            }
            Button("24 hours timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 24 * 3600)
                dismiss()
            }
        }
    }

    private func deleteButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "trash", text: "Delete") {
            presentingDeleteConfirm = true
        }
        .confirmationDialog("", isPresented: $presentingDeleteConfirm) {
            Button("Delete message", role: .destructive) {
                model.deleteMessage(post: selectedPost)
                dismiss()
            }
        }
    }

    private func copyButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "document.on.document", text: "Copy") {
            model.copyMessage(post: selectedPost)
            dismiss()
        }
    }

    private func nicknameButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "person.badge.plus", text: "Nickname") {
            if let user = selectedPost.user {
                nicknameText = chat.nicknames.getNickname(user: user) ?? ""
            } else {
                nicknameText = ""
            }
            presentingNicknameDialog = true
        }
        .alert("Nickname for \(selectedPost.user ?? "")", isPresented: $presentingNicknameDialog) {
            TextField("Nickname", text: $nicknameText)
            Button("Save") {
                saveNickname(selectedPost: selectedPost)
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
    }

    private func infoButton() -> some View {
        ActionButtonView(image: "info.circle", text: "Info") {
            showingChatterInfo = true
        }
    }

    private func saveNickname(selectedPost: ChatPost) {
        guard let user = selectedPost.user else {
            return
        }
        let nickname = nicknameText.trimmingCharacters(in: .whitespaces)
        if nickname.isEmpty {
            chat.nicknames.nicknames.removeAll(where: { $0.user == user })
        } else if let existingNickname = chat.nicknames.nicknames.first(where: { $0.user == user }) {
            existingNickname.nickname = nickname
        } else {
            let item = SettingsChatNickname()
            item.user = user
            item.nickname = nickname
            chat.nicknames.nicknames.append(item)
        }
        model.reloadChatMessages()
    }

    private func lineView(selectedPost: ChatPost) -> some View {
        let content = style.makeContent(post: selectedPost,
                                        platform: model.chat.moreThanOneStreamingPlatform,
                                        deleted: selectedPost.state.deleted)
        return ChatLineView(content: content) { url in
            if let url {
                linkUrl = url
            }
        }
    }

    var body: some View {
        if let selectedPost {
            if showingChatterInfo {
                QuickButtonChatChatterInfoView(
                    model: model,
                    post: selectedPost,
                    presenting: $showingChatterInfo
                )
                .border(.gray)
                .padding(.horizontal, 5)
            } else {
                VStack {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.selectedPost = nil
                        }
                    VStack(alignment: .leading) {
                        ScrollView {
                            lineView(selectedPost: selectedPost)
                        }
                        .frame(height: 100)
                        .padding(.vertical, 5)
                        HStack {
                            Spacer(minLength: 0)
                            banButton(selectedPost: selectedPost)
                            Spacer(minLength: 0)
                            timeoutButton(selectedPost: selectedPost)
                            Spacer(minLength: 0)
                            deleteButton(selectedPost: selectedPost)
                            Spacer(minLength: 0)
                            copyButton(selectedPost: selectedPost)
                            Spacer(minLength: 0)
                            nicknameButton(selectedPost: selectedPost)
                            Spacer(minLength: 0)
                            infoButton()
                                .disabled(selectedPost.platform != .kick)
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 5)
                    }
                    .border(.gray)
                    .padding(.horizontal, 5)
                    .background(.black)
                }
            }
        }
    }
}
