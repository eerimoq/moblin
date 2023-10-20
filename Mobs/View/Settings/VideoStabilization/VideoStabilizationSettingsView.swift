import SwiftUI

struct VideoStabilizationPickerView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    @State var videoStabilizationMode: String

    init(model: Model, toolbar: Toolbar) {
        self.model = model
        self.toolbar = toolbar
        videoStabilizationMode = model.database.videoStabilizationMode!.rawValue
    }

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
        .toolbar {
            toolbar
        }
    }
}

struct VideoStabilizationSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    var body: some View {
        NavigationLink(destination: VideoStabilizationPickerView(
            model: model,
            toolbar: toolbar
        )) {
            TextItemView(
                name: "Video stabilization",
                value: model.database.videoStabilizationMode!.rawValue
            )
        }
    }
}
