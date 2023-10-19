import SwiftUI

struct StreamSrtSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency >= 0 else {
            return
        }
        stream.srt!.latency = latency
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    toolbar: toolbar,
                    title: "Latency",
                    value: String(stream.srt!.latency),
                    onSubmit: submitLatency,
                    footer: Text(
                        """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """
                    )
                )) {
                    TextItemView(name: "Latency", value: String(stream.srt!.latency))
                }
            }
        }
        .navigationTitle("SRT & SRTLA")
        .toolbar {
            toolbar
        }
    }
}
