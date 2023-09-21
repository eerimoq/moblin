import SwiftUI

struct StreamUrlSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State var value: String
    @State var show: Bool = false
    @State var showError: Bool = false
    @State var errorMessage: String = ""

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        value = stream.url!
    }

    func submitUrl(value: String) {
        guard let url = URL(string: value) else {
            showError = true
            errorMessage = "Malformed URL."
            return
        }
        guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
            showError = true
            errorMessage = "Malformed URL."
            return
        }
        switch url.scheme {
        case "rtmp":
            if let message = isValidRtmpUrl(url: value) {
                showError = true
                errorMessage = message
                return
            }
        case "rtmps":
            if let message = isValidRtmpUrl(url: value) {
                showError = true
                errorMessage = message
                return
            }
        case "srt":
            break
        case "srtla":
            break
        case nil:
            errorMessage = "Scheme missing."
            showError = true
            return
        default:
            showError = true
            errorMessage = "Unsupported scheme \(url.scheme!)."
            return
        }
        showError = false
        errorMessage = ""
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
                    if showError {
                        Text(errorMessage)
                            .bold()
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    Text(
                        "Do not share your URL with anyone or they can hijack your channel!"
                    ).bold()
                    Text("")
                    Text("Examples:")
                    Group {
                        Text("Twitch").underline()
                        Text("- rtmp://arn03.contribute.live-video.net/app/my_stream_key")
                    }
                    Group {
                        Text("Kick").underline()
                        Text("- rtmps://fa723fc1b171.global-contribute.live-video.net/my_stream_key")
                    }
                    Group {
                        Text("OBS Media Source").underline()
                        Text("- srt://134.40.20.32.2:5000/my_stream_key")
                    }
                    Group {
                        Text("SRTLA endpoint").underline()
                        Text("- srtla://foobar.org/my_stream_key")
                    }
                }
            }
        }
        .navigationTitle("URL")
    }
}
