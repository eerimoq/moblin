import SwiftUI

struct StreamEmotesSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("BTTV", isOn: Binding(get: {
                    stream.chat.bttvEmotes
                }, set: { value in
                    stream.chat.bttvEmotes = value
                    if stream.enabled {
                        model.bttvEmotesEnabledUpdated()
                    }
                }))
                Toggle("FFZ", isOn: Binding(get: {
                    stream.chat.ffzEmotes
                }, set: { value in
                    stream.chat.ffzEmotes = value
                    if stream.enabled {
                        model.ffzEmotesEnabledUpdated()
                    }
                }))
                Toggle("7TV", isOn: Binding(get: {
                    stream.chat.seventvEmotes
                }, set: { value in
                    stream.chat.seventvEmotes = value
                    if stream.enabled {
                        model.seventvEmotesEnabledUpdated()
                    }
                }))
            }
        }
        .navigationTitle("Emotes")
    }
}
