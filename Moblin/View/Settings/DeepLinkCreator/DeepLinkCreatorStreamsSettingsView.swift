import SwiftUI

struct DeepLinkCreatorStreamsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var deepLinkCreator: DeepLinkCreator

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(deepLinkCreator.streams) { stream in
                        DeepLinkCreatorStreamSettingsView(stream: stream)
                    }
                    .onMove(perform: { froms, to in
                        deepLinkCreator.streams.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        deepLinkCreator.streams.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    deepLinkCreator.streams.append(DeepLinkCreatorStream())
                }
            }
        }
        .navigationTitle("Streams")
    }
}
