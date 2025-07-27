import SwiftUI

struct DeepLinkCreatorStreamsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var deepLinkCreator: DeepLinkCreator

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(deepLinkCreator.streams) { stream in
                        DeepLinkCreatorStreamSettingsView(deepLinkCreator: deepLinkCreator, stream: stream)
                    }
                    .onMove { froms, to in
                        deepLinkCreator.streams.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        deepLinkCreator.streams.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let stream = DeepLinkCreatorStream()
                    stream.name = makeUniqueName(name: DeepLinkCreatorStream.baseName,
                                                 existingNames: deepLinkCreator.streams)
                    deepLinkCreator.streams.append(stream)
                }
            }
        }
        .navigationTitle("Streams")
    }
}
