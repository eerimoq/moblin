import SwiftUI

private struct StreamItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
        let item = NavigationLink {
            StreamSettingsView(database: database, stream: stream)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Toggle(stream.name, isOn: Binding(get: {
                    stream.enabled
                }, set: { _ in
                    model.setCurrentStream(stream: stream)
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled || model.isLive || model.isRecording)
            }
        }
        if stream.enabled {
            item.swipeActions(edge: .trailing) {
                Button {
                    database.streams.append(stream.clone())
                } label: {
                    Text("Duplicate")
                }
                .tint(.blue)
            }
        } else {
            item.swipeActions(edge: .trailing) {
                Button {
                    database.streams.removeAll { $0 == stream }
                } label: {
                    Text("Delete")
                }
                .tint(.red)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    database.streams.append(stream.clone())
                } label: {
                    Text("Duplicate")
                }
                .tint(.blue)
            }
        }
    }
}

struct StreamsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.streams) { stream in
                        StreamItemView(database: database, stream: stream)
                    }
                    .onMove { froms, to in
                        database.streams.move(fromOffsets: froms, toOffset: to)
                    }
                }
                CreateButtonView {
                    model.resetWizard()
                    createStreamWizard.isPresenting = true
                }
                .disabled(model.isLive || model.isRecording)
                .sheet(isPresented: $createStreamWizard.isPresenting) {
                    NavigationStack {
                        StreamWizardSettingsView(createStreamWizard: createStreamWizard)
                    }
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
            }
        }
        .navigationTitle("Streams")
    }
}
