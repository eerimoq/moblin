import SwiftUI

struct StreamsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Form {
            Section {
                ForEach(database.streams) { stream in
                    NavigationLink(destination: StreamSettingsView(
                        stream: stream
                    )) {
                        HStack {
                            DraggableItemPrefixView()
                            Toggle(stream.name, isOn: Binding(get: {
                                stream.enabled
                            }, set: { value in
                                stream.enabled = value
                                for ostream in database.streams
                                    where ostream.id != stream.id
                                {
                                    ostream.enabled = false
                                }
                                model.reloadStream()
                                model.sceneUpdated()
                            }))
                            .disabled(stream.enabled || model.isLive)
                        }
                    }
                    .deleteDisabled(stream.enabled)
                }
                .onMove(perform: { froms, to in
                    database.streams.move(fromOffsets: froms, toOffset: to)
                    model.store()
                })
                .onDelete(perform: { offsets in
                    database.streams.remove(atOffsets: offsets)
                    model.store()
                })
                CreateButtonView(action: {
                    database.streams.append(SettingsStream(name: "My stream"))
                    model.store()
                })
            } footer: {
                Text("Only one stream can be used at a time.")
            }
        }
        .navigationTitle("Streams")
        .toolbar {
            SettingsToolbar()
        }
    }
}
