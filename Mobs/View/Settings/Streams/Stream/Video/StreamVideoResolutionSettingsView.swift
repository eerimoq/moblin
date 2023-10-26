import SwiftUI

struct StreamVideoResolutionSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(resolutions, id: \.self) { resolution in
                        Text(resolution)
                    }
                }
                .onChange(of: selection) { resolution in
                    stream.resolution = SettingsStreamResolution(rawValue: resolution)!
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Resolution")
    }
}
