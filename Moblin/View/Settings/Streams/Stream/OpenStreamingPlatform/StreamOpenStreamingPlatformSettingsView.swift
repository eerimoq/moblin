import SwiftUI

struct StreamOpenStreamingPlatformSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        stream.openStreamingPlatformUrl = value
        model.store()
        if stream.enabled {
            model.openStreamingPlatformUrlUpdated()
        }
    }

    func submitRoom(value: String) {
        stream.openStreamingPlatformChannelId = value
        model.store()
        if stream.enabled {
            model.openStreamingPlatformRoomUpdated()
        }
    }

    func submitUsername(value: String) {
        stream.openStreamingPlatformUsername = value
        model.store()
        if stream.enabled {
            model.openStreamingPlatformUsernameUpdated()
        }
    }

    func submitPassword(value: String) {
        stream.openStreamingPlatformPassword = value
        model.store()
        if stream.enabled {
            model.openStreamingPlatformPasswordUpdated()
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
                TextEditNavigationView(
                    title: String(localized: "Username"),
                    value: stream.openStreamingPlatformUsername!,
                    onSubmit: submitUsername
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: stream.openStreamingPlatformPassword!,
                    onSubmit: submitPassword,
                    sensitive: true
                )
            }
        }
        .navigationTitle("Open Streaming Platform")
        .toolbar {
            SettingsToolbar()
        }
    }
}
