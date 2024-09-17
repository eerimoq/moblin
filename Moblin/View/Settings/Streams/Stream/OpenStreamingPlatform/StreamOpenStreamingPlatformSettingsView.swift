import SwiftUI

struct StreamOpenStreamingPlatformSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        stream.openStreamingPlatformUrl = value
        if stream.enabled {
            model.openStreamingPlatformUrlUpdated()
        }
    }

    func submitRoom(value: String) {
        stream.openStreamingPlatformChannelId = value
        if stream.enabled {
            model.openStreamingPlatformRoomUpdated()
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: stream.openStreamingPlatformUrl!,
                    onSubmit: submitUrl,
                    placeholder: "ws://foo.org:5443/ws"
                )
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.openStreamingPlatformChannelId!,
                    onSubmit: submitRoom,
                    placeholder: "4e9f02fc-cee9-4d1c-b4b5-99b9496375c8"
                )
            }
        }
        .navigationTitle("Open Streaming Platform")
        .toolbar {
            SettingsToolbar()
        }
    }
}
