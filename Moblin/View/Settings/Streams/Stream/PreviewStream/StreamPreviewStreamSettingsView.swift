import SwiftUI

struct StreamPreviewStreamSettingsView: View {
    @ObservedObject var stream: SettingsStream

    private func isValidPreviewStreamUrl(value: String) -> String? {
        if value.isEmpty {
            return nil
        }
        return isValidUrl(url: value, allowedSchemes: ["whip", "whips"])
    }

    private func submitUrl(value: String) {
        stream.previewStreamUrl = value
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
                Toggle("Enabled", isOn: $stream.previewStreamEnabled)
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: stream.previewStreamUrl,
                    onChange: isValidPreviewStreamUrl,
                    onSubmit: submitUrl,
                    placeholder: "whip://your-server/live"
                )
                Picker("Resolution", selection: $stream.previewStreamResolution) {
                    ForEach(resolutions(), id: \.self) {
                        Text($0.shortString())
                    }
                }
                Picker("Video bitrate", selection: $stream.previewStreamBitrate) {
                    ForEach(videoBitrates(), id: \.self) {
                        Text(formatBytesPerSecond(speed: Int64($0)))
                    }
                }
            }
        }
        .navigationTitle("Preview stream")
    }
}
