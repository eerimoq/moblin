import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preview: Preview

    var body: some View {
        TabView {
            PreviewView(model: model, preview: model.preview)
            if !preview.viaRemoteControl {
                ChatView(chatSettings: model.settings.chat, chat: model.chat)
            }
            if model.showPadelScoreBoard && !preview.viaRemoteControl {
                PadelScoreboardView(model: model, padel: model.padel)
            }
            ControlView(preview: preview)
        }
        .onAppear {
            model.setup()
        }
    }
}
