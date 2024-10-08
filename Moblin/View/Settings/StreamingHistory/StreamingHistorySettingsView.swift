import SwiftUI

private struct StreamingHistorySettingsSummaryView: View {
    @EnvironmentObject var model: Model

    private var history: StreamingHistory {
        model.streamingHistory
    }

    var body: some View {
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
    }
}

private struct StreamingHistorySettingsStreamsView: View {
    @EnvironmentObject var model: Model

    private func formatStreamTitle(stream: StreamingHistoryStream) -> String {
        return "\(stream.startTime.formatted()), \(stream.duration().format())"
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.streamingHistory.database.streams) { stream in
                        NavigationLink {
                            StreamingHistoryStreamSettingsView(stream: stream)
                        } label: {
                            HStack {
                                if stream.isSuccessful() {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundColor(.red)
                                }
                                VStack(alignment: .leading) {
                                    Text(formatStreamTitle(stream: stream))
                                    Text(stream.settings.name)
                                        .font(.footnote)
                                }
                            }
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.streamingHistory.database.streams.remove(atOffsets: offsets)
                        model.streamingHistory.store()
                    })
                }
            }
        }
    }
}

struct StreamingHistorySettingsView: View {
    var body: some View {
        VStack {
            StreamingHistorySettingsSummaryView()
            StreamingHistorySettingsStreamsView()
        }
        .navigationTitle("Streaming history")
    }
}
