import SwiftUI

struct VideoStabilizationSettingsView: View {
    @EnvironmentObject var model: Model
    @State var mode: SettingsVideoStabilizationMode

    var body: some View {
        Picker("Video stabilization", selection: $mode) {
            ForEach(videoStabilizationModes, id: \.self) {
                Text($0.toString())
                    .tag($0)
            }
        }
        .onChange(of: mode) {
            model.database.videoStabilizationMode = $0
            model.reattachCamera()
        }
    }
}
