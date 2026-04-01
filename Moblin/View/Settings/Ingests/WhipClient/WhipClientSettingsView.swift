import SwiftUI

struct WhipClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whipClient: SettingsWhipClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        return String(numberOfEnabledStreams)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Text("The WHIP client connects to a remote server to receive video streams.")
                }
                Section {
                    List {
                        ForEach(whipClient.streams) { stream in
                            WhipClientStreamSettingsView(whipClient: whipClient, stream: stream)
                        }
                        .onDelete { indexes in
                            whipClient.streams.remove(atOffsets: indexes)
                            model.reloadWhipClient()
                            model.updateMicsListAsync()
                        }
                    }
                    CreateButtonView {
                        let stream = SettingsWhipClientStream()
                        stream.name = makeUniqueName(name: SettingsWhipClientStream.baseName,
                                                     existingNames: whipClient.streams)
                        whipClient.streams.append(stream)
                        model.updateMicsListAsync()
                    }
                } header: {
                    Text("Streams")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
            .navigationTitle("WHIP client")
        } label: {
            HStack {
                Text("WHIP client")
                Spacer()
                GrayTextView(text: status())
            }
        }
        .onAppear {
            numberOfEnabledStreams = whipClient.streams.filter { $0.enabled }.count
        }
    }
}
