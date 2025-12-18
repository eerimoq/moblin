import SwiftUI

private struct StreamItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    @State private var presentingDeleteConfirmation: Bool = false

    var body: some View {
        NavigationLink {
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
        .swipeActions(edge: .trailing) {
            if !stream.enabled {
                Button {
                    presentingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            Button {
                database.streams.append(stream.clone())
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }
        .confirmationDialog("", isPresented: $presentingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                database.streams.removeAll { $0 === stream }
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
                        StreamWizardSettingsView(model: model, createStreamWizard: createStreamWizard)
                    }
                }
            } footer: {
                SwipeLeftToDuplicateOrDeleteHelpView(kind: String(localized: "a stream"))
            }
        }
        .navigationTitle("Streams")
    }
}
