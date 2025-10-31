import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            PreviewView(preview: model.preview)
            if !model.viaRemoteControl {
                ChatView(chatSettings: model.settings.chat, chat: model.chat)
            }
            if model.scoreboardType != nil && !model.viaRemoteControl {
                ScoreboardView()
            }
            ControlView(preview: model.preview)
        }
        .onAppear {
            model.setup()
        }
    }
}
