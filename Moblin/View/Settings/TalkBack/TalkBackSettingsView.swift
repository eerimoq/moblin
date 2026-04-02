import SwiftUI

struct TalkBackSettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var talkBack: SettingsTalkBack

    private func onChange(micId: String) {
        talkBack.micId = micId
        model.updateTalkBack()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $talkBack.enabled)
                    .onChange(of: talkBack.enabled) { _ in
                        model.updateTalkBack()
                    }
            }
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: "Mic",
                        onChange: onChange,
                        items: model.database.mics.mics
                            .filter { $0.isNetwork() }
                            .map {
                                InlinePickerItem(id: $0.id, text: $0.name)
                            },
                        selectedId: talkBack.micId
                    )
                } label: {
                    HStack {
                        Text("Mic")
                        Spacer()
                        GrayTextView(text: model.getMicById(id: talkBack.micId)?.name ?? "Unknown 😢")
                    }
                }
            }
        }
        .navigationTitle("Talk back")
    }
}
