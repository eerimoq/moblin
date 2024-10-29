import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            PreviewView()
            ChatView()
            if model.showPadelScoreBoard {
                PadelScoreboardView()
            }
            ControlView()
        }
        .onAppear {
            model.setup()
        }
    }
}
