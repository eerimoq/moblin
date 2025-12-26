import SwiftUI

private struct StealthButtonView: View {
    let image: String
    let text: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        VStack {
            Image(systemName: image)
                .font(.system(size: 20))
                .padding([.bottom], 2)
            Text(text)
                .font(.body)
        }
        .frame(width: stealthModeButtonSize, height: stealthModeButtonSize)
        .foregroundStyle(.white)
        .background(.black)
        .clipShape(Circle())
        .onTapGesture { _ in
            action()
        }
    }
}

private struct ReturnButtonView: View {
    let model: Model

    var body: some View {
        StealthButtonView(image: "arrowshape.turn.up.backward", text: "Return") {
            model.toggleStealthMode()
        }
    }
}

private struct ChatButtonView: View {
    @ObservedObject var quickButtons: SettingsQuickButtons
    let showButtons: () -> Void

    var body: some View {
        StealthButtonView(image: quickButtons.blackScreenShowChat ? "message.fill" : "message",
                          text: "Chat")
        {
            quickButtons.blackScreenShowChat.toggle()
            showButtons()
        }
    }
}

struct StealthModeView: View {
    let model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons
    @ObservedObject var chat: ChatProvider
    @ObservedObject var stealthMode: StealthMode
    @ObservedObject var orientation: Orientation

    private func showButtons() {
        stealthMode.showButtons = true
        stealthMode.hideButtonsTimer.startSingleShot(timeout: 3) {
            stealthMode.showButtons = false
        }
    }

    private func tryUnpause() {
        guard chat.interactiveChat else {
            return
        }
        if chat.paused {
            model.endOfChatReachedWhenPaused()
            chat.triggerScrollToBottom.toggle()
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                }
            }
            .background(.black)
            if let image = stealthMode.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .ignoresSafeArea()
        .onTapGesture(count: 1) {
            showButtons()
        }
        .onAppear {
            showButtons()
            model.disableScreenPreview()
        }
        .onDisappear {
            model.maybeEnableScreenPreview()
            // Trigger after tryPause() of bottom of chat detector.
            DispatchQueue.main.async {
                self.tryUnpause()
            }
        }
        if stealthMode.showButtons {
            if orientation.isPortrait {
                VStack {
                    Spacer()
                    HStack {
                        ChatButtonView(quickButtons: quickButtons, showButtons: showButtons)
                        Spacer()
                        ReturnButtonView(model: model)
                    }
                    .padding([.horizontal], 50)
                    .frame(height: controlBarWidthDefault)
                }
            } else {
                HStack {
                    Spacer()
                    VStack {
                        ChatButtonView(quickButtons: quickButtons, showButtons: showButtons)
                        Spacer()
                        ReturnButtonView(model: model)
                    }
                    .padding([.top], 50)
                    .padding([.bottom], 25)
                    .frame(width: controlBarWidth(quickButtons: quickButtons))
                }
            }
        }
        if quickButtons.blackScreenShowChat {
            ChatOverlayView(chatSettings: model.database.chat,
                            chat: model.chat,
                            orientation: orientation,
                            quickButtons: quickButtons,
                            fullSize: true)
        }
    }
}
