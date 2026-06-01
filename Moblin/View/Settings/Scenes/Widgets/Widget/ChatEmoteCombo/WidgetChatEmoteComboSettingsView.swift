import SwiftUI

struct WidgetChatEmoteComboSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var chatEmoteCombo: SettingsWidgetChatEmoteCombo

    private func setEffectSettings() {
        model.getChatEmoteComboEffect(id: widget.id)?.setSettings(settings: chatEmoteCombo)
    }

    var body: some View {
        Section {
            Picker("Minimum combo", selection: $chatEmoteCombo.minimumCombo) {
                ForEach([2, 3, 4, 5, 6, 7, 8, 9, 10], id: \.self) {
                    Text(String($0))
                }
            }
            .onChange(of: chatEmoteCombo.minimumCombo) { _ in
                setEffectSettings()
            }
            Picker("Timeout", selection: $chatEmoteCombo.resetAfter) {
                ForEach([3, 4, 5, 6, 7, 8, 9, 10], id: \.self) {
                    Text("\($0)s")
                }
            }
            .onChange(of: chatEmoteCombo.resetAfter) { _ in
                setEffectSettings()
            }
        }
    }
}
