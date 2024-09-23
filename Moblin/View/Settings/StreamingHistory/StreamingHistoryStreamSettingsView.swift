import SwiftUI

struct StreamingHistoryStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: StreamingHistoryStream

    var body: some View {
        VStack {
            if let logId = stream.logId {
                HStack {
                    Spacer()
                    ShareLink("Share log", item: model.makeStreamShareLogUrl(logId: logId))
                }
            }
            Form {
                Section {
                    TextValueView(name: String(localized: "Start time"), value: stream.startTime.formatted())
                    TextValueView(
                        name: String(localized: "Duration"),
                        value: stream.duration().formatWithSeconds()
                    )
                    TextValueView(
                        name: String(localized: "Total sent"),
                        value: stream.totalBytes.formatBytes()
                    )
                    TextValueView(
                        name: String(localized: "Average bitrate"),
                        value: stream.averageBitrateString()
                    )
                    TextValueView(
                        name: String(localized: "Highest bitrate"),
                        value: stream.highestBitrateString()
                    )
                    HStack {
                        if stream.numberOfFffffs! != 0 {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                        }
                        TextValueView(name: String(localized: "FFFFF:s"), value: "\(stream.numberOfFffffs!)")
                    }
                    TextValueView(
                        name: String(localized: "Chat messages"),
                        value: stream.numberOfChatMessagesString()
                    )
                } header: {
                    Text("General")
                }
                Section {
                    HStack {
                        Text("Highest thermal state")
                        Spacer()
                        Image(systemName: "flame")
                            .padding([.leading, .trailing], 4)
                            .padding([.top, .bottom], 2)
                            .foregroundColor(stream.highestThermalState!.toProcessInfo().color())
                            .background(.black)
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(.secondary)
                            )
                    }
                    TextValueView(
                        name: String(localized: "Lowest battery percentage"),
                        value: stream.lowestBatteryPercentageString()
                    )
                } header: {
                    Text("Device health")
                }
                Section {
                    TextValueView(name: String(localized: "Name"), value: stream.settings.name)
                    TextValueView(
                        name: String(localized: "Resolution"),
                        value: stream.settings.resolutionString()
                    )
                    TextValueView(name: String(localized: "FPS"), value: "\(stream.settings.fps)")
                    TextValueView(
                        name: String(localized: "Protocol"),
                        value: stream.settings.protocolString()
                    )
                    TextValueView(name: String(localized: "Codec"), value: stream.settings.codecString())
                    TextValueView(name: String(localized: "Bitrate"), value: stream.settings.bitrateString())
                    TextValueView(
                        name: String(localized: "Audio codec"),
                        value: stream.settings.audioCodecString()
                    )
                    TextValueView(
                        name: String(localized: "Audio bitrate"),
                        value: stream.settings.audioBitrateString()
                    )
                } header: {
                    Text("Settings")
                }
            }
        }
        .navigationTitle("Stream summary")
    }
}
