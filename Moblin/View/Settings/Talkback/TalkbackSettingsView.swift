import SwiftUI

struct TalkbackSettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var talkback: SettingsTalkback

    private func onChange(micId: String) {
        talkback.micId = micId
        model.updateTalkback()
    }

    var body: some View {
        Form {
            Section {
                Text("Play audio from an Ingest in your speakers.")
            }
            Section {
                Toggle("Enabled", isOn: $talkback.enabled)
                    .onChange(of: talkback.enabled) { _ in
                        model.updateTalkback()
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
                        selectedId: talkback.micId
                    )
                } label: {
                    HStack {
                        Text("Mic")
                        Spacer()
                        GrayTextView(text: model.getMicById(id: talkback.micId)?.name ?? "Unknown 😢")
                    }
                }
            }
            ShortcutSectionView {
                IngestsShortcutView(model: model)
            }
        }
        .navigationTitle("Talkback")
    }
}
