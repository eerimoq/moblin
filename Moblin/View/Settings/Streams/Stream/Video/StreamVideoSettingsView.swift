import SwiftUI

struct StreamVideoSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamVideoResolutionSettingsView(
                    stream: stream,
                    selection: stream.resolution.rawValue
                )) {
                    TextItemView(name: "Resolution", value: stream.resolution.rawValue)
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: StreamVideoFpsSettingsView(
                    stream: stream,
                    selection: stream.fps
                )) {
                    TextItemView(name: "FPS", value: String(stream.fps))
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: StreamVideoCodecSettingsView(
                    stream: stream,
                    selection: stream.codec.rawValue
                )) {
                    TextItemView(name: "Codec", value: stream.codec.rawValue)
                }
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: StreamVideoBitrateSettingsView(
                    stream: stream,
                    selection: stream.bitrate
                )) {
                    TextItemView(
                        name: "Bitrate",
                        value: formatBytesPerSecond(speed: Int64(stream.bitrate))
                    )
                }
                if logger.debugEnabled {
                    NavigationLink(
                        destination: StreamVideoCaptureSessionPresetSettingsView(
                            stream: stream,
                            selection: stream.captureSessionPreset.rawValue
                        )
                    ) {
                        Toggle(isOn: Binding(get: {
                            stream.captureSessionPresetEnabled
                        }, set: { value in
                            stream.captureSessionPresetEnabled = value
                            model.storeAndReloadStreamIfEnabled(stream: stream)
                        })) {
                            TextItemView(
                                name: "Preset",
                                value: stream.captureSessionPreset.rawValue
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Video")
    }
}
