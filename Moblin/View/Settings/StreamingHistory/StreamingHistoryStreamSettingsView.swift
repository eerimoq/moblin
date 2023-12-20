import SwiftUI

struct StreamingHistoryStreamSettingsView: View {
    var stream: StreamingHistoryStream

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Start time")
                    Spacer()
                    Text(stream.startTime.formatted())
                }
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(stream.duration().format())
                }
                HStack {
                    Text("Total sent")
                    Spacer()
                    Text(stream.totalBytes.formatBytes())
                }
            } header: {
                Text("Statistics")
            }
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(stream.settings.name)
                }
                HStack {
                    Text("Resolution")
                    Spacer()
                    Text(stream.settings.resolutionString())
                }
                HStack {
                    Text("FPS")
                    Spacer()
                    Text("\(stream.settings.fps)")
                }
                HStack {
                    Text("Protocol")
                    Spacer()
                    Text(stream.settings.protocolString())
                }
                HStack {
                    Text("Codec")
                    Spacer()
                    Text(stream.settings.codecString())
                }
                HStack {
                    Text("Bitrate")
                    Spacer()
                    Text(stream.settings.bitrateString())
                }
                HStack {
                    Text("Audio bitrate")
                    Spacer()
                    Text("\(stream.settings.audioBitrateString())")
                }
            } header: {
                Text("Settings")
            }
        }
        .navigationTitle("Stream summary")
        .toolbar {
            SettingsToolbar()
        }
    }
}
