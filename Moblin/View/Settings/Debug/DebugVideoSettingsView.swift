import SwiftUI

struct DebugVideoSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug

    private func onPixelFormatChange(format: String) {
        model.database.debug.pixelFormat = format
        model.setPixelFormat()
        model.reloadStream()
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Pixel format"),
                        onChange: onPixelFormatChange,
                        items: InlinePickerItem.fromStrings(values: pixelFormats),
                        selectedId: model.database.debug.pixelFormat
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Pixel format"),
                        value: model.database.debug.pixelFormat
                    )
                }
                Toggle("Allow video range pixel format", isOn: $debug.allowVideoRangePixelFormat)
                    .onChange(of: debug.allowVideoRangePixelFormat) { _ in
                        model.setAllowVideoRangePixelFormat()
                    }
            } footer: {
                Text("Change camera and restart stream for these to work properly.")
            }
        }
        .navigationTitle("Video")
    }
}
