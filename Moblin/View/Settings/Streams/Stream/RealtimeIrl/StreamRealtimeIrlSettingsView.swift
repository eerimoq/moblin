import SwiftUI

struct StreamRealtimeIrlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    func submitBaseUrl(value: String) {
        stream.realtimeIrlBaseUrl = value
        if stream.enabled {
            model.reloadLocation()
        }
    }

    func submitPushKey(value: String) {
        stream.realtimeIrlPushKey = value
        if stream.enabled {
            model.reloadLocation()
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Send your location to https://rtirl.com, to let your viewers know where you are.")
            }
            Section {
                TextEditBindingNavigationView(
                    title: String(localized: "Base URL"),
                    value: $stream.realtimeIrlBaseUrl,
                    onSubmit: submitBaseUrl
                )
                TextEditBindingNavigationView(
                    title: String(localized: "Push key"),
                    value: $stream.realtimeIrlPushKey,
                    onSubmit: submitPushKey,
                    sensitive: true
                )
            }
        }
        .navigationTitle("RealtimeIRL")
    }
}
