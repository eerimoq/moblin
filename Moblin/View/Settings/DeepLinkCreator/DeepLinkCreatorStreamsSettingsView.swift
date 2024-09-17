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
                        NavigationLink(destination: DeepLinkCreatorStreamSettingsView(stream: stream)) {
                            Text(stream.name)
                        }
                    }
                    .onMove(perform: { froms, to in
                        deepLinkCreator.streams.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        deepLinkCreator.streams.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView(action: {
                    deepLinkCreator.streams.append(DeepLinkCreatorStream())
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Streams")
        .toolbar {
            SettingsToolbar()
        }
    }
}
