import SwiftUI

struct StreamSettingsView: View {
    private var stream: SettingsStream
    @ObservedObject private var model: Model
    @State private var proto: String

    init(stream: SettingsStream, model: Model) {
        self.stream = stream
        self.model = model
        self.proto = stream.proto
    }
    
    func submitName(name: String) {
        stream.name = name
        model.store()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: stream.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: stream.name)
            }
            NavigationLink(destination: StreamTwitchSettingsView(model: model, stream: stream)) {
                Text("Twitch")
            }
            NavigationLink(destination: StreamVideoSettingsView(model: model, stream: stream)) {
                Text("Video")
            }
            NavigationLink(destination: StreamRtmpSettingsView(model: model, stream: stream)) {
                Text("RTMP")
            }
            NavigationLink(destination: StreamSrtSettingsView(model: model, stream: stream)) {
                Text("SRT")
            }
            Section("Protocol") {
                Picker("", selection: $proto) {
                    ForEach(["RTMP", "SRT"], id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: proto) { proto in
                    stream.proto = proto
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Stream")
    }
}
