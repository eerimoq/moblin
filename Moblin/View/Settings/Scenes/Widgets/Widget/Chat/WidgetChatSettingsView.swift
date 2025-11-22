import SwiftUI

struct WidgetChatSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var chat: SettingsWidgetChat

    private func setEffectSettings() {
        // model.getChatEffect(id: widget.id)?.setSettings(showtime: snapshot.showtime)
    }

    var body: some View {
        EmptyView()
    }
}
