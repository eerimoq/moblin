import SwiftUI

struct StreamVideoSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamVideoResolutionSettingsView(
                    model: model,
                    stream: stream,
                    toolbar: toolbar
                )) {
                    TextItemView(name: "Resolution", value: stream.resolution.rawValue)
                }
                NavigationLink(destination: StreamVideoFpsSettingsView(
                    model: model,
                    stream: stream,
                    toolbar: toolbar
                )) {
                    TextItemView(name: "FPS", value: String(stream.fps))
                }
                NavigationLink(destination: StreamVideoCodecSettingsView(
                    model: model,
                    stream: stream,
                    toolbar: toolbar
                )) {
                    TextItemView(name: "Codec", value: stream.codec.rawValue)
                }
                NavigationLink(destination: StreamVideoBitrateSettingsView(
                    model: model,
                    stream: stream,
                    toolbar: toolbar
                )) {
                    TextItemView(
                        name: "Bitrate",
                        value: formatBytesPerSecond(speed: Int64(stream.bitrate))
                    )
                }
                if logger.debugEnabled {
                    NavigationLink(
                        destination: StreamVideoCaptureSessionPresetSettingsView(
                            model: model,
                            stream: stream,
                            toolbar: toolbar
                        )
                    ) {
                        Toggle(isOn: Binding(get: {
                            stream.captureSessionPresetEnabled!
                        }, set: { value in
                            stream.captureSessionPresetEnabled = value
                            model.store()
                            model.reloadStreamIfEnabled(stream: stream)
                        })) {
                            TextItemView(
                                name: "Preset",
                                value: stream.captureSessionPreset!.rawValue
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Video")
        .toolbar {
            toolbar
        }
    }
}
