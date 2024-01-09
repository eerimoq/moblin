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
        VStack(alignment: .leading) {
            Text("Send your location to rtirl.com.")
            Form {
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
        }
        .navigationTitle("RealtimeIRL")
        .toolbar {
            SettingsToolbar()
        }
    }
}
