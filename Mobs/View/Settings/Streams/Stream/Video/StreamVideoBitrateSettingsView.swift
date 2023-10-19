import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream
    @State private var selection: UInt32

    init(model: Model, stream: SettingsStream, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
        selection = stream.bitrate
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(model.database.bitratePresets!) { preset in
                        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                            .tag(preset.bitrate)
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
        .toolbar {
            toolbar
        }
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    done()
                }, label: {
                    Text("Close")
                        .padding(5)
                        .foregroundColor(.blue)
                })
            }
            .background(Color(uiColor: .systemGroupedBackground))
            Form {
                Section("Bitrate") {
                    Picker("", selection: $selection) {
                        ForEach(model.database.bitratePresets!) { preset in
                            Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                                .tag(preset.bitrate)
                        }
                    }
                    .onChange(of: selection) { bitrate in
                        model.stream.bitrate = bitrate
                        model.store()
                        if model.stream.enabled {
                            model.setStreamBitrate(stream: model.stream)
                        }
                        model
                            .makeToast(title: formatBytesPerSecond(speed: Int64(bitrate)))
                        done()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
    }
}
