import SwiftUI

struct TalkBackSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var talkBack: SettingsTalkBack

    private func onVideoSourceChange(id: String) {
        guard let uuid = UUID(uuidString: id) else {
            return
        }
        model.setTalkBackVideoSourceId(uuid)
    }

    private func onAudioSourceChange(id: String) {
        guard let uuid = UUID(uuidString: id) else {
            return
        }
        model.setTalkBackAudioSourceId(uuid)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: "Video source",
                        onChange: onVideoSourceChange,
                        items: model.ingestVideoSources().map {
                            InlinePickerItem(id: $0.0.uuidString, text: $0.1)
                        },
                        selectedId: talkBack.videoSourceId.uuidString
                    )
                } label: {
                    HStack {
                        Text("Video source")
                        Spacer()
                        GrayTextView(text: model.talkBackVideoSourceName())
                    }
                }
                NavigationLink {
                    InlinePickerView(
                        title: "Audio source",
                        onChange: onAudioSourceChange,
                        items: model.ingestAudioSources().map {
                            InlinePickerItem(id: $0.0.uuidString, text: $0.1)
                        },
                        selectedId: talkBack.audioSourceId.uuidString
                    )
                } label: {
                    HStack {
                        Text("Audio source")
                        Spacer()
                        GrayTextView(text: model.talkBackAudioSourceName())
                    }
                }
            } footer: {
                Text("""
                Audio received on the selected audio source is played through the device's speaker. \
                The received video on the selected video source is shown above the zoom preset picker \
                in the bottom right on the stream view. Use the 'Talk back' quick button to show or \
                hide the video.
                """)
            }
        }
        .navigationTitle("Talk back")
    }
}
