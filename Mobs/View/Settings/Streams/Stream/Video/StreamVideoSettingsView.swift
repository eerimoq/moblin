import SwiftUI

struct StreamVideoSettingsView: View {
    @ObservedObject var model: Model
    private var stream: SettingsStream
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
    }
    
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamVideoResolutionSettingsView(model: model, stream: stream)) {
                    TextItemView(name: "Resolution", value: stream.resolution)
                }
                NavigationLink(destination: StreamVideoFpsSettingsView(model: model, stream: stream)) {
                    TextItemView(name: "FPS", value: "\(stream.fps)")
                }
            }
        }
        .navigationTitle("Video")
    }
}
