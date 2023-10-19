import SwiftUI

struct StreamVideoResolutionSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream
    @State private var selection: String

    init(model: Model, stream: SettingsStream, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
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
        .toolbar {
            toolbar
        }
    }
}
