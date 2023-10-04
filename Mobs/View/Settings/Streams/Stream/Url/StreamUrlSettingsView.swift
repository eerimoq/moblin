import SwiftUI

struct StreamUrlSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    @State var value: String
    @State var show: Bool = false

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        value = stream.url
    }

    func submitUrl() {
        value = value.trim()
        guard let url = URL(string: value) else {
            model.makeErrorToast(title: "Malformed URL")
            return
        }
        if url.host() == nil {
            model.makeErrorToast(title: "Host missing")
            return
        }
        guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
            model.makeErrorToast(title: "Malformed URL")
            return
        }
        switch url.scheme {
        case "rtmp":
            if let message = isValidRtmpUrl(url: value) {
                model.makeErrorToast(title: message)
                return
            }
        case "rtmps":
            if let message = isValidRtmpUrl(url: value) {
                model.makeErrorToast(title: message)
                return
            }
        case "srt":
            if let message = isValidSrtUrl(url: value) {
                model.makeErrorToast(title: message)
                return
            }
        case "srtla":
            if let message = isValidSrtUrl(url: value) {
                model.makeErrorToast(title: message)
                return
            }
        case nil:
            model.makeErrorToast(title: "Scheme missing")
            return
        default:
            model.makeErrorToast(title: "Unsupported scheme \(url.scheme!)")
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
                        TextField("", text: $value, onEditingChanged: { isEditing in
                            if !isEditing {
                                submitUrl()
                            }
                        })
                        .disableAutocorrection(true)
                        .onSubmit {
                            submitUrl()
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
                            submitUrl()
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
                    ).bold()
                    Text("")
                    Group {
                        Text("Twitch").underline()
                        if let url =
                            URL(
                                string: "https://dashboard.twitch.tv/u/\(stream.twitchChannelName)/settings/stream"
                            )
                        {
                            HStack(spacing: 0) {
                                Text("Template: rtmp://")
                                Link(
                                    "nearby_ingest_endpoint",
                                    destination: URL(
                                        string: "https://help.twitch.tv/s/twitch-ingest-recommendation"
                                    )!
                                )
                                .font(.footnote)
                                Text("/app/")
                                Link("my_stream_key", destination: url)
                                    .font(.footnote)
                            }
                        } else {
                            Text(
                                "Template: rtmp://nearby_ingest_endpoint/app/my_stream_key"
                            )
                        }
                        Text(
                            "Example:  rtmp://arn03.contribute.live-video.net/app/live_123321_sdfopjfwjfpawjefpjawef"
                        )
                        Text("")
                    }
                    Group {
                        Text("Kick").underline()
                        HStack(spacing: 0) {
                            Text("Template: rtmp://")
                            Link(
                                "stream_url",
                                destination: URL(
                                    string: "https://kick.com/dashboard/settings/stream"
                                )!
                            )
                            .font(.footnote)
                            Text("/")
                            Link(
                                "my_stream_key",
                                destination: URL(
                                    string: "https://kick.com/dashboard/settings/stream"
                                )!
                            )
                            .font(.footnote)
                        }
                        Text(
                            """
                            Example:  rtmps://fa723fc1b171.global-contribute.live-video.net/\
                            sk_us-west-123hu43ui34hrkjh
                            """
                        )
                        Text("")
                    }
                    Group {
                        Text("OBS Media Source (SRT)").underline()
                        Text("Template: srt://my_public_ip:my_public_port/my_stream_key")
                        Text("Example:  srt://134.20.342.12:5000/1234")
                        Text("")
                    }
                    Group {
                        Text("BELABOX cloud SRTLA").underline()
                        Text(
                            "Example:  srtla://uk.srt.belabox.net:5000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"
                        )
                        Text("")
                    }
                    Group {
                        Text("BELABOX cloud SRT").underline()
                        Text(
                            "Example:  srt://uk.srt.belabox.net:4000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"
                        )
                        Text("")
                    }
                    Group {
                        Text("SRTLA server").underline()
                        Text(
                            "Template: srtla://my_public_ip:my_public_port/my_stream_key"
                        )
                        Text("Example:  srtla://foobar.org:4432/5678")
                        Text("")
                    }
                    Group {
                        Text("RTMP server").underline()
                        Text("Template: rtmp://my_public_ip:my_public_port/my_stream_key")
                        Text("Example:  rtmp://foobar.org:3321/5678")
                    }
                }
            }
        }
        .navigationTitle("URL")
    }
}
