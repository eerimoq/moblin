import SwiftUI

struct StreamChatSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("BTTV emotes", isOn: Binding(get: {
                    stream.chat!.bttvEmotes
                }, set: { value in
                    stream.chat!.bttvEmotes = value
                    model.store()
                    if stream.enabled {
                        model.bttvEmotesEnabledUpdated()
                    }
                }))
                Toggle("FFZ emotes", isOn: Binding(get: {
                    stream.chat!.ffzEmotes
                }, set: { value in
                    stream.chat!.ffzEmotes = value
                    model.store()
                    if stream.enabled {
                        model.ffzEmotesEnabledUpdated()
                    }
                }))
                Toggle("7TV emotes", isOn: Binding(get: {
                    stream.chat!.seventvEmotes
                }, set: { value in
                    stream.chat!.seventvEmotes = value
                    model.store()
                    if stream.enabled {
                        model.seventvEmotesEnabledUpdated()
                    }
                }))
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            SettingsToolbar()
        }
    }
}
