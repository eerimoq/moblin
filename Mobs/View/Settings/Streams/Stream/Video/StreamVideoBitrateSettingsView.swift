import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State private var selection: UInt32

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        selection = stream.bitrate
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

struct StreamVideoBitrateSettingsButtonView: View {
    @ObservedObject var model: Model
    @State private var selection: UInt32
    private var done: () -> Void

    init(model: Model, done: @escaping () -> Void) {
        self.model = model
        self.done = done
        selection = model.stream.bitrate
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
                    model.stream.bitrate = bitrate
                    model.store()
                    if model.stream.enabled {
                        model.setStreamBitrate(stream: model.stream)
                    }
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        done()
                    }, label: {
                        Text("Close")
                    })
                    Spacer()
                }
            }
        }
    }
}
