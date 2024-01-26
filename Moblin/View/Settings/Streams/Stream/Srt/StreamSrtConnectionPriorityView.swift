import SwiftUI

struct PriorityItemView: View {
    @EnvironmentObject var model: Model
    var priority: SettingsStreamSrtConnectionPriority
    @State var prio: Float

    private func makeName() -> String {
        if let name = model.database.networkInterfaceNames!.first(where: { interface in
            interface.interfaceName == priority.name
        })?.name, !name.isEmpty {
            return name
        } else {
            return priority.name
        }
    }

    var body: some View {
        Toggle(isOn: Binding(get: {
            priority.enabled!
        }, set: { value in
            priority.enabled = value
            model.store()
            model.updateSrtlaPriorities()
        })) {
            HStack {
                Text(makeName())
                    .frame(width: 90)
                Slider(
                    value: $prio,
                    in: 1 ... 10,
                    step: 1,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        priority.priority = Int(prio)
                        model.store()
                        model.updateSrtlaPriorities()
                    }
                )
            }
        }
    }
}

struct StreamSrtConnectionPriorityView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    stream.srt.connectionPriorities!.enabled
                }, set: { value in
                    stream.srt.connectionPriorities!.enabled = value
                    model.store()
                    model.updateSrtlaPriorities()
                    model.objectWillChange.send()
                })) {
                    Text("Enabled")
                }
            }
            if stream.srt.connectionPriorities!.enabled {
                Section {
                    ForEach(stream.srt.connectionPriorities!.priorities) { priority in
                        PriorityItemView(priority: priority, prio: Float(priority.priority))
                    }
                } footer: {
                    Text("""
                    A connection with high priority will be used more than a connection with \
                    low priority if the high priority connection is stable. Unstable connections \
                    will get lowest priority regardless of configured priority until they are stable again.
                    """)
                    Text("")
                    Text("Disabled connections will not be used.")
                }
            }
        }
        .navigationTitle("Connection priorities")
        .toolbar {
            SettingsToolbar()
        }
    }
}
