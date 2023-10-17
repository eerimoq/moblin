import SwiftUI

struct VideoStabilizationPickerView: View {
    @ObservedObject var model: Model
    @State var videoStabilizationMode: String

    init(model: Model) {
        self.model = model
        videoStabilizationMode = model.database.videoStabilizationMode!.rawValue
    }

    var body: some View {
        Form {
            Picker("", selection: $videoStabilizationMode) {
                ForEach(videoStabilizationModes, id: \.self) { mode in
                    Text(mode)
                }
            }
            .onChange(of: videoStabilizationMode) { mode in
                model.database
                    .videoStabilizationMode = VideoStabilizationMode(rawValue: mode)!
                model.store()
                model.reattachCamera()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Video stabilization")
    }
}

struct VideoStabilizationSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        NavigationLink(destination: VideoStabilizationPickerView(model: model)) {
            TextItemView(
                name: "Video stabilization",
                value: model.database.videoStabilizationMode!.rawValue
            )
        }
    }
}
