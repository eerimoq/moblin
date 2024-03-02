import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var model: Model
    
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: WatchChatSettingsView(fontSize: model.database.watch!.chat.fontSize)) {
                    Text("Chat")
                }
            }
        }
    }
}
