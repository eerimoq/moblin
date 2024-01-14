import SwiftUI

struct PriorityItemView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    var priority: SettingsStreamSrtConnectionPriority
    @State var prio: Float

    private func makeName() -> String {
        return model.database.networkInterfaceNames!.first(where: { interface in
            interface.interfaceName == priority.name
        })?.name ?? priority.name
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
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                ForEach(stream.srt.connectionPriorities!) { priority in
                    PriorityItemView(stream: stream, priority: priority, prio: Float(priority.priority))
                }
            } footer: {
                Text("""
                A connection with high priority will be used more than a connection with \
                low priority if the high priority connection is stable.
                """)
            }
        }
        .navigationTitle("Connection priorities")
        .toolbar {
            SettingsToolbar()
        }
    }
}
