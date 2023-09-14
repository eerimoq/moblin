import SwiftUI

struct StreamVideoResolutionSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State private var selection: String

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        selection = stream.resolution.rawValue
    }

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
