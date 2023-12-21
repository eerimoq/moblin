import SwiftUI

struct StreamingHistorySettingsView: View {
    @EnvironmentObject var model: Model

    private var history: StreamingHistory {
        model.streamingHistory
    }

    private func formatStreamTitle(stream: StreamingHistoryStream) -> String {
        return "\(stream.startTime.formatted()), \(stream.duration().format())"
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack {
                    Text("\(history.database.totalStreams!)")
                        .font(.title2)
                    Text("Total streams")
                        .font(.subheadline)
                }
                Spacer()
                VStack {
                    Text(history.database.totalTime!.format())
                        .font(.title2)
                    Text("Total time")
                        .font(.subheadline)
                }
                Spacer()
                VStack {
                    Text(history.database.totalBytes!.formatBytes())
                        .font(.title2)
                    Text("Total sent")
                        .font(.subheadline)
                }
                Spacer()
            }
            Form {
                Section {
                    ForEach(model.streamingHistory.database.streams.reversed()) { stream in
                        NavigationLink(destination: StreamingHistoryStreamSettingsView(stream: stream)) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text(formatStreamTitle(stream: stream))
                                    Text(stream.settings.name)
                                        .font(.footnote)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Streaming history")
        .toolbar {
            SettingsToolbar()
        }
    }
}
