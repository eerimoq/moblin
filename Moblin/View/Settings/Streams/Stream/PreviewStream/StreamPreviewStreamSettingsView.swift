import SwiftUI

struct StreamPreviewStreamSettingsView: View {
    @ObservedObject var previewStream: SettingsStreamPreviewStream

    private func isValidPreviewStreamUrl(value: String) -> String? {
        if value.isEmpty {
            return nil
        }
        return isValidUrl(url: value, allowedSchemes: ["whip", "whips"])
    }

    private func submitUrl(value: String) {
        previewStream.url = value
    }

    private func resolutions() -> [SettingsStreamResolution] {
        [.r854x480, .r640x360, .r426x240]
    }

    private func videoBitrates() -> [UInt32] {
        [2_000_000, 1_500_000, 1_000_000, 500_000, 250_000]
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: previewStream.url,
                    onChange: isValidPreviewStreamUrl,
                    onSubmit: submitUrl,
                    placeholder: "whip://your-server/live"
                )
                Picker("Resolution", selection: $previewStream.resolution) {
                    ForEach(resolutions(), id: \.self) {
                        Text($0.shortString())
                    }
                }
                Picker("Video bitrate", selection: $previewStream.bitrate) {
                    ForEach(videoBitrates(), id: \.self) {
                        Text(formatBytesPerSecond(speed: Int64($0)))
                    }
                }
            }
        }
        .navigationTitle("Preview stream")
    }
}
