import SwiftUI

struct StreamsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.streams) { stream in
                        let item = NavigationLink(destination: StreamSettingsView(
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
                        if stream.enabled {
                            item.swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.append(stream.clone())
                                    model.store()
                                }, label: {
                                    Text("Duplicate")
                                })
                                .tint(.blue)
                            }
                        } else {
                            item.swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.removeAll { $0 == stream }
                                    model.store()
                                }, label: {
                                    Text("Delete")
                                })
                                .tint(.red)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.append(stream.clone())
                                    model.store()
                                }, label: {
                                    Text("Duplicate")
                                })
                                .tint(.blue)
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        database.streams.move(fromOffsets: froms, toOffset: to)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    if true {
                        database.streams.append(SettingsStream(name: String(localized: "My stream")))
                        model.store()
                    } else {
                        model.isPresentingWizard = true
                    }
                })
                .sheet(isPresented: $model.isPresentingWizard) {
                    NavigationStack {
                        StreamWizardSettingsView()
                    }
                }
            }
        }
        .navigationTitle("Streams")
        .toolbar {
            SettingsToolbar()
        }
    }
}
