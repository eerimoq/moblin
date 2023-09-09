import SwiftUI

var resolutions = ["1920x1080", "1280x720"]

struct StreamVideoResolutionSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State private var selection: String
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        self.selection = stream.resolution
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
                    stream.resolution = resolution
                    model.store()
                    if stream.enabled {
                        model.reloadStream()
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Resolution")
    }
}
