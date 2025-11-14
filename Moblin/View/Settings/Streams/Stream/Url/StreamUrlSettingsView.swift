import SwiftUI

private struct RtmpHelpView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text("""
                    Template: rtmp://\
                    [nearby_ingest_endpoint](https://help.twitch.tv/s/twitch-ingest-recommendation)\
                    /app/
                    """)
                    if !stream.twitchChannelName.isEmpty,
                       let url =
                       URL(string: "https://dashboard.twitch.tv/u/\(stream.twitchChannelName)/settings/stream")
                    {
                        Link("my_stream_key", destination: url)
                    } else {
                        Text("my_stream_key")
                    }
                }
                Text("Example:  rtmp://arn03.contribute.live-video.net/app/live_123321_sdfopjfwjfpawjefpjawef")
            }
        } header: {
            Text("Twitch")
        }
        Section {
            Text("Example: rtmp://a.rtmp.youtube.com/live2/1bk2-0d03-9683-7k65-e4d3")
        } header: {
            Text("YouTube")
        }
        Section {
            Text("Example: rtmps://live-api-s.facebook.com:443/rtmp/FB-11152522122511115-0-BctNCp9jzzz-AAA")
        } header: {
            Text("Facebook")
        }
        Section {
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text("""
                    Template: \
                    [Stream URL](https://dashboard.kick.com/channel/stream)/\
                    [Stream Key](https://dashboard.kick.com/channel/stream)
                    """)
                }
                Text(
                    """
                    Example:  rtmps://fa723fc1b171.global-contribute.live-video.net/sk_us-west-123hu43ui34hrkjh
                    """
                )
            }
        } header: {
            Text("Kick")
        }
        Section {
            VStack(alignment: .leading) {
                Text("Template: rtmp://my_public_ip:my_public_port/my_stream_key")
                Text("Example:  rtmp://foobar.org:3321/5678")
            }
        } header: {
            Text("RTMP server")
        }
    }
}

private struct SrtHelpView: View {
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Template: srt://my_public_ip:my_public_port")
                Text("Example:  srt://134.20.342.12:5000")
            }
        } header: {
            Text("OBS Media Source (SRT)")
        }
        Section {
            Text("Example: srtla://uk.srt.belabox.net:5000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3")
        } header: {
            Text("BELABOX cloud SRTLA")
        }
        Section {
            Text("Example: srt://uk.srt.belabox.net:4000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3")
        } header: {
            Text("BELABOX cloud SRT")
        }
        Section {
            VStack(alignment: .leading) {
                Text("Template: srtla://my_public_ip:my_public_port")
                Text("Example:  srtla://foobar.org:4432")
            }
        } header: {
            Text("SRTLA server")
        }
        Section {
            VStack(alignment: .leading) {
                Text("Template: srt://my_public_ip:my_public_port?streamid=publish/live/my_key")
                Text("Example:  srt://120.12.32.12:4000?streamid=publish/live/feed")
            }
        } header: {
            Text("SRT Live Server (SLS)")
        }
    }
}

private struct UrlSettingsView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    @ObservedObject var stream: SettingsStream
    @Binding var url: String
    let allowedSchemes: [String]?
    let showSrtHelp: Bool
    @State var value: String
    @State var changed: Bool = false
    @State var submitted: Bool = false
    @State var error: String?
    @State var presentingHelp: Bool = false

    private func submitUrl() {
        guard !submitted else {
            return
        }
        value = cleanUrl(url: value)
        if isValidUrl(url: value, allowedSchemes: allowedSchemes) != nil {
            dismiss()
            return
        }
        submitted = true
        url = value
        model.reloadStreamIfEnabled(stream: stream)
        dismiss()
    }

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $value)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        submitUrl()
                    }
                    .submitLabel(.done)
                    .onChange(of: value) { _ in
                        error = isValidUrl(url: value, allowedSchemes: allowedSchemes)
                        changed = true
                        if value.contains("\n") {
                            value = value.replacingOccurrences(of: "\n", with: "")
                            submitUrl()
                        }
                    }
                    .disableAutocorrection(true)
            } footer: {
                if let error {
                    FormFieldError(error: error)
                }
                Text("Do not share your URL with anyone or they can hijack your channel!")
                    .bold()
            }
            Section {
                TextButtonView("Help") {
                    presentingHelp = true
                }
                .sheet(isPresented: $presentingHelp) {
                    NavigationView {
                        Form {
                            RtmpHelpView(stream: stream)
                            if showSrtHelp {
                                SrtHelpView()
                            }
                        }
                        .navigationTitle("Help")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    presentingHelp = false
                                } label: {
                                    Image(systemName: "xmark")
                                }
                            }
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

struct StreamUrlSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        UrlSettingsView(stream: stream,
                        url: $stream.url,
                        allowedSchemes: nil,
                        showSrtHelp: true,
                        value: stream.url)
    }
}

struct StreamMultiStreamingUrlView: View {
    @ObservedObject var stream: SettingsStream
    @ObservedObject var destination: SettingsStreamMultiStreamingDestination

    var body: some View {
        UrlSettingsView(stream: stream,
                        url: $destination.url,
                        allowedSchemes: ["rtmp", "rtmps"],
                        showSrtHelp: false,
                        value: destination.url)
    }
}
