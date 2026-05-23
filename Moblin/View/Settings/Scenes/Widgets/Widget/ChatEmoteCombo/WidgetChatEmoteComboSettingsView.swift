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
            HStack {
                Text("Font size")
                Slider(
                    value: $chatEmoteCombo.fontSize,
                    in: 10 ... 60,
                    step: 1,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        setEffectSettings()
                    }
                )
                .onChange(of: chatEmoteCombo.fontSize) { _ in
                    setEffectSettings()
                }
                Text(String(Int(chatEmoteCombo.fontSize)))
                    .frame(width: 25)
            }
            HStack {
                Text("Minimum combo")
                Slider(
                    value: Binding(
                        get: { Double(chatEmoteCombo.minCombo) },
                        set: { chatEmoteCombo.minCombo = max(2, Int($0)) }
                    ),
                    in: 2 ... 50,
                    step: 1,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        setEffectSettings()
                    }
                )
                .onChange(of: chatEmoteCombo.minCombo) { _ in
                    setEffectSettings()
                }
                Text(String(chatEmoteCombo.minCombo))
                    .frame(width: 25)
            }
            HStack {
                Text("Timeout")
                Slider(
                    value: $chatEmoteCombo.resetAfterSeconds,
                    in: 1 ... 15,
                    step: 0.5,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        setEffectSettings()
                    }
                )
                .onChange(of: chatEmoteCombo.resetAfterSeconds) { _ in
                    setEffectSettings()
                }
                Text(String(format: "%.1fs", chatEmoteCombo.resetAfterSeconds))
                    .frame(width: 40)
            }
        } footer: {
            Text(
                "Shows an emote and a combo counter when chatters repeatedly use the same emote. " +
                    "Timeout is how long to wait before hiding after no new matches."
            )
        }
    }
}
