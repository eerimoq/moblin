import SwiftUI

private struct StreamingHistoryStreamSettingsGeneralView: View {
    let stream: StreamingHistoryStream

    var body: some View {
        Section {
            TextValueView(name: "Start time", value: stream.startTime.formatted())
            TextValueView(name: "Duration", value: stream.duration().formatWithSeconds())
            TextValueView(name: "Total sent", value: stream.totalBytes.formatBytes())
            TextValueView(name: "Average bitrate", value: stream.averageBitrateString())
            TextValueView(name: "Highest bitrate", value: stream.highestBitrateString())
            HStack {
                if stream.numberOfFffffs! != 0 {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
                TextValueView(name: "FFFFF:s", value: "\(stream.numberOfFffffs!)")
            }
            TextValueView(name: "Chat messages", value: stream.numberOfChatMessagesString())
        } header: {
            Text("General")
        }
    }
}

private struct StreamingHistoryStreamSettingsDeviceHealthView: View {
    let stream: StreamingHistoryStream

    var body: some View {
        Section {
            HStack {
                Text("Highest thermal state")
                Spacer()
                Image(systemName: "flame")
                    .padding([.leading, .trailing], 4)
                    .padding([.top, .bottom], 2)
                    .foregroundStyle(stream.highestThermalState!.toProcessInfo().color())
                    .background(.black)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.secondary)
                    )
            }
            TextValueView(
                name: "Lowest battery percentage",
                value: stream.lowestBatteryPercentageString()
            )
        } header: {
            Text("Device health")
        }
    }
}

private struct StreamingHistoryStreamSettingsSettingsView: View {
    let stream: StreamingHistoryStream

    var body: some View {
        Section {
            TextValueView(name: "Name", value: stream.settings.name)
            TextValueView(name: "Resolution", value: stream.settings.resolutionString())
            TextValueView(name: "FPS", value: "\(stream.settings.fps)")
            TextValueView(name: "Protocol", value: stream.settings.protocolString())
            TextValueView(name: "Codec", value: stream.settings.codecString())
            TextValueView(name: "Bitrate", value: stream.settings.bitrateString())
            TextValueView(name: "Audio codec", value: stream.settings.audioCodecString())
            TextValueView(name: "Audio bitrate", value: stream.settings.audioBitrateString())
        } header: {
            Text("Settings")
        }
    }
}

struct StreamingHistoryStreamSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: StreamingHistoryStream

    var body: some View {
        VStack {
            if let logId = stream.logId {
                HStack {
                    Spacer()
                    ShareLink("Share log", item: model.makeStreamShareLogUrl(logId: logId))
                }
            }
            Form {
                StreamingHistoryStreamSettingsGeneralView(stream: stream)
                StreamingHistoryStreamSettingsDeviceHealthView(stream: stream)
                StreamingHistoryStreamSettingsSettingsView(stream: stream)
            }
        }
        .navigationTitle("Stream summary")
    }
}
