import SwiftUI

struct DebugAdaptiveBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    @State var srtOverheadBandwidth: Float
    @State var packetsInFlight: Double

    var body: some View {
        Form {
            Section {
                Toggle("Max bandwidth follows input", isOn: Binding(get: {
                    model.database.debug!.maximumBandwidthFollowInput!
                }, set: { value in
                    model.database.debug!.maximumBandwidthFollowInput = value
                    model.store()
                }))
            }
            Section {
                HStack {
                    Slider(
                        value: $srtOverheadBandwidth,
                        in: 5 ... 50,
                        step: 5,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.debug!
                                .srtOverheadBandwidth = Int32(srtOverheadBandwidth)
                            model.store()
                        }
                    )
                    Text(String(Int32(srtOverheadBandwidth)))
                        .frame(width: 40)
                }
            } header: {
                Text("SRT oheadbw")
            }
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
