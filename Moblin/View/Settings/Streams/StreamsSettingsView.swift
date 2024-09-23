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
                            stream: stream,
                            name: stream.name
                        )) {
                            HStack {
                                DraggableItemPrefixView()
                                Toggle(stream.name, isOn: Binding(get: {
                                    stream.enabled
                                }, set: { _ in
                                    model.setCurrentStream(stream: stream)
                                    model.reloadStream()
                                    model.sceneUpdated()
                                    model.resetSelectedScene(changeScene: false)
                                    model.updateOrientation()
                                }))
                                .disabled(stream.enabled || model.isLive || model.isRecording)
                            }
                        }
                        if stream.enabled && (model.isLive || model.isRecording) {
                            item.swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.append(stream.clone())
                                }, label: {
                                    Text("Duplicate")
                                })
                                .tint(.blue)
                            }
                        } else {
                            item.swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.removeAll { $0 == stream }
                                    model.reloadStream()
                                    model.sceneUpdated()
                                }, label: {
                                    Text("Delete")
                                })
                                .tint(.red)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(action: {
                                    database.streams.append(stream.clone())
                                }, label: {
                                    Text("Duplicate")
                                })
                                .tint(.blue)
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        database.streams.move(fromOffsets: froms, toOffset: to)
                    })
                }
                CreateButtonView(action: {
                    model.resetWizard()
                    model.isPresentingWizard = true
                })
                .disabled(model.isLive || model.isRecording)
                .sheet(isPresented: $model.isPresentingWizard) {
                    NavigationStack {
                        StreamWizardSettingsView()
                    }
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
            }
        }
        .navigationTitle("Streams")
    }
}
