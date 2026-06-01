import SwiftUI

private func resolutions() -> [SettingsStreamResolution] {
    [.r854x480, .r640x360, .r426x240]
}

private func videoBitrates() -> [UInt32] {
    [2_000_000, 1_500_000, 1_000_000, 500_000, 250_000]
}

struct StreamPreviewStreamSettingsView: View {
    let model: Model
    @ObservedObject var previewStream: SettingsStreamPreviewStream

    var body: some View {
        Form {
            Section {
                Text("""
                A low-quality low-latency stream sent to a WHIP server. Can be used to \
                preview the stream from another device.
                """)
            }
            Section {
                NavigationLink {
                    UrlSettingsView(
                        model: model,
                        disabled: false,
                        url: $previewStream.url,
                        value: previewStream.url,
                        placeholder: "whip://your-server/live",
                        allowedSchemes: ["whip", "whips"],
                        examples: whipExamples,
                        onSubmitted: {}
                    )
                } label: {
                    TextItemLocalizedView(name: "URL", value: previewStream.url, sensitive: true)
                }
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
