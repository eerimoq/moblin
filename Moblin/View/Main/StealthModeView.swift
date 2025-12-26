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

    private func statusButton() -> some View {
        StealthButtonView(image: stealthMode.showStatus ? "chart.bar.fill" : "chart.bar",
                          text: "Status")
        {
            stealthMode.showStatus.toggle()
            showButtons()
        }
    }

    private func chatButton() -> some View {
        StealthButtonView(image: quickButtons.blackScreenShowChat ? "message.fill" : "message",
                          text: "Chat")
        {
            quickButtons.blackScreenShowChat.toggle()
            showButtons()
        }
    }

    private func returnButton() -> some View {
        StealthButtonView(image: "arrowshape.turn.up.backward", text: "Return") {
            model.toggleStealthMode()
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
        ChatOverlayView(chatSettings: model.database.chat,
                        chat: model.chat,
                        orientation: orientation,
                        quickButtons: quickButtons,
                        fullSize: true)
        if stealthMode.showStatus {
            HStack(spacing: 0) {
                Spacer()
                RightOverlayTopView(model: model, database: model.database)
                    .padding([.top, .trailing])
                if !orientation.isPortrait {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(width: controlBarWidth(quickButtons: quickButtons))
                }
            }
        }
        if stealthMode.showButtons {
            if orientation.isPortrait {
                VStack {
                    Spacer()
                    HStack {
                        chatButton()
                        statusButton()
                        Spacer()
                        returnButton()
                    }
                    .padding([.horizontal], 30)
                    .frame(height: controlBarWidthDefault)
                }
            } else {
                HStack {
                    Spacer()
                    VStack {
                        chatButton()
                        statusButton()
                        Spacer()
                        returnButton()
                    }
                    .padding([.top], 30)
                    .padding([.bottom], 5)
                    .frame(width: controlBarWidth(quickButtons: quickButtons))
                }
            }
        }
    }
}
