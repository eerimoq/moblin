import SwiftUI

struct StreamingHistoryStreamSettingsView: View {
    var stream: StreamingHistoryStream

    var body: some View {
        Form {
            Section {
                TextValueView(name: "Start time", value: stream.startTime.formatted())
                TextValueView(name: "Duration", value: stream.duration().formatWithSeconds())
                TextValueView(name: "Total sent", value: stream.totalBytes.formatBytes())
                TextValueView(name: "Average bitrate", value: stream.averageBitrateString())
                TextValueView(name: "Highest bitrate", value: stream.highestBitrateString())
                HStack {
                    if stream.numberOfFffffs! != 0 {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red)
                    }
                    TextValueView(name: "Number of FFFFF:s", value: "\(stream.numberOfFffffs!)")
                }
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
                    name: "Lowest battery percentage",
                    value: stream.lowestBatteryPercentageString()
                )
            } header: {
                Text("Device health")
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
                    Text("Audio codec")
                    Spacer()
                    Text(stream.settings.audioCodecString())
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
