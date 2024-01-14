import SwiftUI

struct PriorityItemView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
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
                }
            )
            .disabled(stream.enabled && model.isLive)
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
                })) {
                    Text("Enabled")
                }
                .disabled(stream.enabled && model.isLive)
            }
            Section {
                ForEach(stream.srt.connectionPriorities!.priorities) { priority in
                    PriorityItemView(stream: stream, priority: priority, prio: Float(priority.priority))
                }
            } footer: {
                Text("""
                A connection with high priority will be used more than a connection with \
                low priority if the high priority connection is stable. Unstable connections \
                will get lowset priority regardless of configured priority until they are stable again.
                """)
            }
        }
        .navigationTitle("Connection priorities")
        .toolbar {
            SettingsToolbar()
        }
    }
}
