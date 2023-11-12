import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView()) {
                    Text("Log")
                }
                Toggle("Debug", isOn: Binding(get: {
                    logger.debugEnabled
                }, set: { value in
                    logger.debugEnabled = value
                }))
                NavigationLink(destination: DebugAudioSettingsView()) {
                    Text("Audio")
                }
                NavigationLink(
                    destination: DebugAdaptiveBitrateSettingsView(
                        packetsInFlight: Double(model
                            .getAdaptiveBitratePacketsInFlight())
                    )
                ) {
                    Text("Adaptive bitrate")
                }
                HStack {
                    Text("Exposure")
                    Slider(
                        value: $model.bias,
                        in: -2 ... 2,
                        step: 0.2,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setExposureBias(bias: model.bias)
                        }
                    )
                    .onChange(of: model.bias) { _ in
                        model.setExposureBias(bias: model.bias)
                    }
                    Text(formatOneDecimal(value: model.bias))
                        .frame(width: 40)
                }
            }
        }
        .navigationTitle("Debug")
        .toolbar {
            SettingsToolbar()
        }
    }
}
