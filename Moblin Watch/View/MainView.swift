import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    PreviewView()
                    ChatView()
                }
            }
            .ignoresSafeArea()
            .edgesIgnoringSafeArea([.top, .leading, .trailing])
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            model.setup()
        }
    }
}
