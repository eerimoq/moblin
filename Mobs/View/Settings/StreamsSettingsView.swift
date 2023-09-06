import SwiftUI

struct StreamsSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.database
        }
    }

    var body: some View {
        VStack {
            Form {
                ForEach(database.streams) { stream in
                    NavigationLink(destination: StreamSettingsView(stream: stream, model: model)) {
                        Toggle(stream.name, isOn: Binding(get: {
                            stream.enabled
                        }, set: { value in
                            stream.enabled = value
                            for ostream in database.streams {
                                if ostream.id != stream.id {
                                    ostream.enabled = false
                                }
                            }
                            model.store()
                            model.reloadStream()
                            model.objectWillChange.send()
                        }))
                        .disabled(stream.enabled)
                    }
                }
                .onDelete(perform: { offsets in
                    database.streams.remove(atOffsets: offsets)
                    model.store()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.streams.append(SettingsStream(name: "My stream"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Streams")
    }
}
