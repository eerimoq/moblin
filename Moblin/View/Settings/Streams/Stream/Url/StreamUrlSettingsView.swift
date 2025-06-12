import SwiftUI

struct StreamUrlSettingsView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var stream: SettingsStream
    @State var value: String
    @State var show: Bool = false
    @State var changed: Bool = false
    @State var submitted: Bool = false
    @State var error = ""

    func submitUrl() {
        guard !submitted else {
            return
        }
        value = cleanUrl(url: value)
        if let message = isValidUrl(url: value) {
            error = message
            return
        }
        submitted = true
        stream.url = value
        model.reloadStreamIfEnabled(stream: stream)
        dismiss()
    }

    var body: some View {
        Form {
            Section {
                ZStack(alignment: .leading) {
                    TextField("", text: $value, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            submitUrl()
                        }
                        .submitLabel(.done)
                        .onChange(of: value) { _ in
                            changed = true
                            if value.contains("\n") {
                                value = value.replacingOccurrences(of: "\n", with: "")
                                submitUrl()
                            }
                        }
                        .disableAutocorrection(true)
                        .opacity(show ? 1 : 0)
                    Text(replaceSensitive(value: value, sensitive: true))
                        .opacity(show ? 0 : 1)
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
                    FormFieldError(error: error)
                    Text(
                        "Do not share your URL with anyone or they can hijack your channel!"
                    ).bold()
                    Text("")
                    Group {
                        Text("Twitch").underline()
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
                            if !stream.twitchChannelName.isEmpty, let url =
                                URL(
                                    string: "https://dashboard.twitch.tv/u/\(stream.twitchChannelName)/settings/stream"
                                )
                            {
                                Link("my_stream_key", destination: url)
                                    .font(.footnote)
                            } else {
                                Text("my_stream_key")
                            }
                        }
                        Text(
                            "Example:  rtmp://arn03.contribute.live-video.net/app/live_123321_sdfopjfwjfpawjefpjawef"
                        )
                        Text("")
                    }
                    Group {
                        Text("YouTube").underline()
                        Text(
                            """
                            Example: rtmp://a.rtmp.youtube.com/live2/1bk2-0d03-9683-7k65-e4d3
                            """
                        )
                        Text("")
                    }
                    Group {
                        Text("Facebook").underline()
                        Text(
                            """
                            Example: rtmps://live-api-s.facebook.com:443/rtmp/FB-11152522122511115-0-BctNCp9jzzz-AAA
                            """
                        )
                        Text("")
                    }
                    Group {
                        Text("Kick").underline()
                        HStack(spacing: 0) {
                            Text("Template: rtmps://")
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
                        Text("Template: srt://my_public_ip:my_public_port")
                        Text("Example:  srt://134.20.342.12:5000")
                        Text("")
                    }
                    Group {
                        Group {
                            Text("BELABOX cloud SRTLA").underline()
                            Text(
                                "Example: srtla://uk.srt.belabox.net:5000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"
                            )
                            Text("")
                        }
                        Group {
                            Text("BELABOX cloud SRT").underline()
                            Text(
                                "Example: srt://uk.srt.belabox.net:4000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"
                            )
                            Text("")
                        }
                        Group {
                            Text("SRTLA server").underline()
                            Text(
                                "Template: srtla://my_public_ip:my_public_port"
                            )
                            Text("Example:  srtla://foobar.org:4432")
                            Text("")
                        }
                        Group {
                            Text("SRT Live Server (SLS)").underline()
                            Text(
                                "Template: srt://my_public_ip:my_public_port?streamid=publish/live/my_key"
                            )
                            Text(
                                "Example:  srt://120.12.32.12:4000?streamid=publish/live/feed"
                            )
                            Text("")
                        }
                        Group {
                            Text("RTMP server").underline()
                            Text(
                                "Template: rtmp://my_public_ip:my_public_port/my_stream_key"
                            )
                            Text("Example:  rtmp://foobar.org:3321/5678")
                        }
                    }
                }
            }
        }
        .onDisappear {
            if changed && !submitted {
                submitUrl()
            }
        }
        .navigationTitle("URL")
    }
}
