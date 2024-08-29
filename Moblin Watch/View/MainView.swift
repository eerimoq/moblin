import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            PreviewView()
            ChatView()
            ControlView()
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            model.setup()
        }
    }
}
