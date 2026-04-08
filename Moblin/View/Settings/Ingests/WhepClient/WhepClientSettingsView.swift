import SwiftUI

struct WhepClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whepClient: SettingsWhepClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        return String(numberOfEnabledStreams)
    }

    private func deleteStream(at indexes: IndexSet) {
        whepClient.streams.remove(atOffsets: indexes)
        model.reloadWhepClient()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Text(String("VERY ENIPMERXETAL!!! DO NOT USE!!!"))
                }
                Section {
                    Text("The WHEP client allows Moblin to receive video streams from a WHEP endpoint.")
                }
                Section {
                    List {
                        ForEach(whepClient.streams) { stream in
                            WhepClientStreamSettingsView(whepClient: whepClient, stream: stream)
                                .contextMenuDeleteButton {
                                    if let index = whepClient.streams
                                        .firstIndex(where: { $0.id == stream.id })
                                    {
                                        deleteStream(at: IndexSet(integer: index))
                                    }
                                }
                        }
                        .onDelete(perform: deleteStream)
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
