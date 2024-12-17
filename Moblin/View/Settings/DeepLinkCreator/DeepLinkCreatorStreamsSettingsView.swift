import SwiftUI

struct DeepLinkCreatorStreamsSettingsView: View {
    @EnvironmentObject var model: Model

    private var deepLinkCreator: DeepLinkCreator {
        return model.database.deepLinkCreator!
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(deepLinkCreator.streams) { stream in
                        NavigationLink {
                            DeepLinkCreatorStreamSettingsView(stream: stream)
                        } label: {
                            Text(stream.name)
                        }
                    }
                    .onMove(perform: { froms, to in
                        deepLinkCreator.streams.move(fromOffsets: froms, toOffset: to)
                        model.store()
                    })
                    .onDelete(perform: { offsets in
                        deepLinkCreator.streams.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                CreateButtonView {
                    deepLinkCreator.streams.append(DeepLinkCreatorStream())
                    model.store()
                    model.objectWillChange.send()
                }
            }
        }
        .navigationTitle("Streams")
    }
}
