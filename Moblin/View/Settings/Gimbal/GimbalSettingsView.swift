import SwiftUI

struct GimbalSettingsView: View {
    @ObservedObject var debug: SettingsDebug

    var body: some View {
        Form {
            Section {
                Text("Control Moblin with Gimbals that supports DockKit.")
            }
            Section {
                VStack(alignment: .leading) {
                    Text("Zoom step")
                    HStack {
                        Slider(
                            value: $debug.dockKitZoomStep,
                            in: 1.001 ... 1.099,
                            step: 0.001
                        )
                        Text(String(format: "%02d", Int(round((debug.dockKitZoomStep - 1.0) * 1000))))
                            .frame(width: 30)
                    }
                }
            }
        }
        .navigationTitle("Gimbal")
    }
}
