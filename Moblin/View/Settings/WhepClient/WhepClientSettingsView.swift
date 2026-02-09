import SwiftUI

struct WhepClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whepClient: SettingsWhepClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        return String(numberOfEnabledStreams)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(whepClient.streams) { stream in
                            WhepClientStreamSettingsView(whepClient: whepClient, stream: stream)
                        }
                        .onDelete { indexes in
                            whepClient.streams.remove(atOffsets: indexes)
                            model.reloadWhepClient()
                        }
                    }
                    CreateButtonView {
                        let stream = SettingsWhepClientStream()
                        stream.name = makeUniqueName(name: SettingsWhepClientStream.baseName,
                                                     existingNames: whepClient.streams)
                        whepClient.streams.append(stream)
                    }
                } header: {
                    Text("Streams")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
            .navigationTitle("WHEP client")
        } label: {
            HStack {
                Text("WHEP client")
                Spacer()
                GrayTextView(text: status())
            }
        }
        .onAppear {
            numberOfEnabledStreams = whepClient.streams.filter { $0.enabled }.count
        }
    }
}

