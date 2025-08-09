import Network
import SwiftUI

struct RtspClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient
    @ObservedObject var stream: SettingsRtspClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: rtspClient.streams)
                }
                Section {
                    TextEditNavigationView(title: String(localized: "URL"), value: stream.url) { value in
                        stream.url = value
                    }
                }
            }
            .navigationTitle("Stream")
        } label: {
            Text(stream.name)
        }
    }
}
