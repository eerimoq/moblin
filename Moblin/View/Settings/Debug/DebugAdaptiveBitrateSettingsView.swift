import SwiftUI

struct DebugAdaptiveBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    @State var packetsInFlight: Double

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $packetsInFlight,
                        in: 50 ... 500,
                        step: 10
                    )
                    .onChange(of: packetsInFlight) { value in
                        model.setAdaptiveBitratePacketsInFlight(value: Int32(value))
                    }
                    Text(String(Int16(packetsInFlight)))
                        .frame(width: 45)
                }
            } header: {
                Text("Packets in flight")
            }
        }
        .navigationTitle("Adaptive bitrate")
    }
}
