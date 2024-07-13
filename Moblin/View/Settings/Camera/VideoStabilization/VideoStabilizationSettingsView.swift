import SwiftUI

struct VideoStabilizationSettingsView: View {
    @EnvironmentObject var model: Model

    private func onChange(mode: String) {
        model.database
            .videoStabilizationMode = SettingsVideoStabilizationMode.fromString(value: mode)
        model.store()
        model.reattachCamera()
        model.objectWillChange.send()
    }

    var body: some View {
        HStack {
            Text("Video stabilization")
            Spacer()
            Picker("", selection: Binding(get: {
                model.database.videoStabilizationMode.toString()
            }, set: onChange)) {
                ForEach(videoStabilizationModes, id: \.self) {
                    Text($0)
                }
            }
        }
    }
}
