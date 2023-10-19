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
                Toggle("Adaptive bitrate*", isOn: Binding(get: {
                    stream.adaptiveBitrate!
                }, set: { value in
                    stream.adaptiveBitrate = value
                    model.store()
                    if stream.enabled {
                        model.setAdaptiveBitrate(stream: stream)
                    }
                }))
            } footer: {
                Text(
                    "* Adaptive bitrate is experimental and only implemented for SRT(LA)."
                )
            }
        }
        .navigationTitle("Video")
        .toolbar {
            toolbar
        }
    }
}
