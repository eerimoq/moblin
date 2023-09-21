import SwiftUI

struct StreamUrlSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State var value: String
    @State var show: Bool = false

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        value = stream.url!
    }

    func submitUrl(value: String) {
        guard let url = URL(string: value) else {
            logger.warning("\(value) is not a valid URL")
            return
        }
        guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
            logger.warning("\(value) is not a valid URL")
            return
        }
        switch url.scheme {
        case "rtmp":
            if !isValidRtmpUrl(url: value) {
                return
            }
        case "rtmps":
            if !isValidRtmpUrl(url: value) {
                return
            }
        case "srt":
            break
        case "srtla":
            break
        case nil:
            logger.warning("No scheme in URL \(value)")
            return
        default:
            logger.warning("Unsupported scheme \(url.scheme!)")
            return
        }
        stream.url = value
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                ZStack {
                    if show {
                        TextField("", text: $value)
                            .onSubmit {
                                submitUrl(value: value.trim())
                            }
                    } else {
                        Text(replaceSensitive(value: value, sensitive: true))
                            .lineLimit(1)
                    }
                }
                HStack {
                    Spacer()
                    if show {
                        Button("Hide sensitive URL") {
                            show = false
                        }
                    } else {
                        Button("Show sensitive URL", role: .destructive) {
                            show = true
                        }
                    }
                    Spacer()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text(
                        "Do not share your URL with anyone or they can hijack your channel!"
                    )
                    Text("")
                    Text("Example URLs:")
                    Text("- rtmp://arn03.contribute.live-video.net/app/my_stream_key")
                    Text("- rtmps://t0.contribute.live-video.net/app/my_stream_key")
                    Text("- srt://134.20.32.2:5000/my_stream_key")
                    Text("- srtla://foobar.org/my_stream_key")
                }
            }
        }
        .navigationTitle("URL")
    }
}
