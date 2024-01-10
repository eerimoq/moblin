import SwiftUI

struct StreamRealtimeIrlSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitPushKey(value: String) {
        stream.realtimeIrlPushKey = value
        model.store()
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
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Push key"),
                    value: stream.realtimeIrlPushKey!,
                    onSubmit: submitPushKey
                )) {
                    TextItemView(
                        name: String(localized: "Push key"),
                        value: stream.realtimeIrlPushKey!,
                        sensitive: true
                    )
                }
            }
        }
        .navigationTitle("RealtimeIRL")
        .toolbar {
            SettingsToolbar()
        }
    }
}
