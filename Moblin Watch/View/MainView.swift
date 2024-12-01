import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            PreviewView()
            if !model.viaRemoteControl {
                ChatView()
            }
            if model.showPadelScoreBoard && !model.viaRemoteControl {
                PadelScoreboardView()
            }
            ControlView()
        }
        .onAppear {
            model.setup()
        }
    }
}
