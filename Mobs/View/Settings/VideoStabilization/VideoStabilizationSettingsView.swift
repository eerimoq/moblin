import SwiftUI

struct VideoStabilizationPickerView: View {
    @EnvironmentObject var model: Model
    @State var videoStabilizationMode: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $videoStabilizationMode) {
                    ForEach(videoStabilizationModes, id: \.self) { mode in
                        Text(mode)
                    }
                }
                .onChange(of: videoStabilizationMode) { mode in
                    model.database
                        .videoStabilizationMode =
                        SettingsVideoStabilizationMode(rawValue: mode)!
                    model.store()
                    model.reattachCamera()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Video stabilization sometimes gives audio-video sync issues.")
            }
        }
        .navigationTitle("Video stabilization")
    }
}

struct VideoStabilizationSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        NavigationLink(destination: VideoStabilizationPickerView(
            videoStabilizationMode: model.database.videoStabilizationMode!.rawValue
        )) {
            TextItemView(
                name: "Video stabilization",
                value: model.database.videoStabilizationMode!.rawValue
            )
        }
    }
}
