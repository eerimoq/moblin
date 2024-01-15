import SwiftUI

struct DebugAdaptiveBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    @State var packetsInFlight: Float

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $packetsInFlight,
                        in: 50 ... 500,
                        step: 10,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setAdaptiveBitratePacketsInFlight(value: Int32(packetsInFlight))
                            model.database.debug!.packetsInFlight = Int(packetsInFlight)
                            model.store()
                        }
                    )
                    Text(String(Int16(packetsInFlight)))
                        .frame(width: 45)
                }
            } header: {
                Text("Packets in flight")
            }
        }
        .navigationTitle("Adaptive bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}
