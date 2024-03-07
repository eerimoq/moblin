import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            GeometryReader { metrics in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        PreviewView()
                        ChatView(width: metrics.size.width)
                    }
                }
            }
            .ignoresSafeArea()
            .edgesIgnoringSafeArea([.top, .leading, .trailing])
            // ControlView()
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            model.setup()
        }
    }
}
