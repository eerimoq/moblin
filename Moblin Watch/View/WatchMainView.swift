import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var model: WatchModel

    var body: some View {
        TabView {
            PreviewView(preview: model.preview)
            if !model.viaRemoteControl {
                ChatView(chatSettings: model.settings.chat, chat: model.chat)
            }
            if model.scoreboardType != nil && !model.viaRemoteControl {
                ScoreboardView()
            }
            ControlView()
        }
        .onAppear {
            model.setup()
        }
    }
}
