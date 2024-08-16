import SwiftUI

struct VideoStabilizationSettingsView: View {
    @EnvironmentObject var model: Model
    @State var mode: String

    var body: some View {
        HStack {
            Text("Video stabilization")
            Spacer()
            Picker("", selection: $mode) {
                ForEach(videoStabilizationModes, id: \.self) {
                    Text($0)
                }
            }
            .onChange(of: mode) {
                model.database.videoStabilizationMode = SettingsVideoStabilizationMode.fromString(value: $0)
                model.store()
                model.reattachCamera()
            }
        }
    }
}
