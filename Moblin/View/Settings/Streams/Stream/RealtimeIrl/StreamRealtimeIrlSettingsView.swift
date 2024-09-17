import SwiftUI

struct StreamRealtimeIrlSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

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
                TextEditNavigationView(
                    title: String(localized: "Push key"),
                    value: stream.realtimeIrlPushKey!,
                    onSubmit: submitPushKey,
                    sensitive: true
                )
            }
        }
        .navigationTitle("RealtimeIRL")
        .toolbar {
            SettingsToolbar()
        }
    }
}
