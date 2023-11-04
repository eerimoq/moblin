import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: UInt32

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(model.database.bitratePresets) { preset in
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
    }
}

struct StreamVideoBitrateSettingsButtonView: View {
    @EnvironmentObject var model: Model
    @State var selection: UInt32
    var done: () -> Void

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
                        ForEach(model.database.bitratePresets) { preset in
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
