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
                    onSubmit: submitUrl
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
            } footer: {
                VStack(alignment: .leading) {
                    Text("Very experimental and very secret!")
                    Text("")
                    Text("Example URL: ws://foo.org:5443/ws")
                }
            }
        }
        .navigationTitle("Open Streaming Platform")
        .toolbar {
            SettingsToolbar()
        }
    }
}
