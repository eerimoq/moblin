import SwiftUI

private struct StreamingHistorySettingsSummaryView: View {
    @ObservedObject var database: StreamingHistoryDatabase

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("\(database.totalStreams)")
                    .font(.title2)
                Text("Total streams")
                    .font(.subheadline)
            }
            Spacer()
            VStack {
                Text(database.totalTime.format())
                    .font(.title2)
                Text("Total time")
                    .font(.subheadline)
            }
            Spacer()
            VStack {
                Text(database.totalBytes.formatBytes())
                    .font(.title2)
                Text("Total sent")
                    .font(.subheadline)
            }
            Spacer()
        }
    }
}

private struct StreamingHistorySettingsStreamsView: View {
    let model: Model
    @ObservedObject var database: StreamingHistoryDatabase

    private func formatStreamTitle(stream: StreamingHistoryStream) -> String {
        return "\(stream.startTime.formatted()), \(stream.duration().format())"
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.streams) { stream in
                        NavigationLink {
                            StreamingHistoryStreamSettingsView(stream: stream)
                        } label: {
                            HStack {
                                if stream.isSuccessful() {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundStyle(.red)
                                }
                                VStack(alignment: .leading) {
                                    Text(formatStreamTitle(stream: stream))
                                    Text(stream.settings.name)
                                        .font(.footnote)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        database.streams.remove(atOffsets: offsets)
                        model.streamingHistory.store()
                    }
                }
            }
        }
    }
}

struct StreamingHistorySettingsView: View {
    let model: Model

    var body: some View {
        VStack {
            StreamingHistorySettingsSummaryView(database: model.streamingHistory.database)
            StreamingHistorySettingsStreamsView(model: model, database: model.streamingHistory.database)
        }
        .navigationTitle("Streaming history")
    }
}
