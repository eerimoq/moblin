import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State private var selection: UInt32
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        self.selection = stream.bitrate
    }
    
    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(bitrates, id: \.self) { bitrate in
                        Text(formatBytesPerSecond(speed: Int64(bitrate))).tag(bitrate)
                    }
                }
                .onChange(of: selection) { bitrate in
                    stream.bitrate = bitrate
                    model.store()
                    if stream.enabled {
                        model.setStreamBitrate(stream: stream)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
    }
}
