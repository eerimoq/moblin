import SwiftUI

private struct RtmpHelpView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section("Twitch") {
            UrlCopyView("rtmp://arn03.contribute.live-video.net/app/live_123321_sdfopjfwjfpawjefpjawef")
        }
        Section("YouTube") {
            UrlCopyView("rtmp://a.rtmp.youtube.com/live2/1bk2-0d03-9683-7k65-e4d3")
        }
        Section("Facebook") {
            UrlCopyView("rtmps://live-api-s.facebook.com:443/rtmp/FB-11152522122511115-0-BctNCp9jzzz-AAA")
        }
        Section("Kick") {
            UrlCopyView("rtmps://fa723fc1b171.global-contribute.live-video.net/sk_us-west-123hu43ui34hrkjh")
        }
        Section("RTMP server") {
            UrlCopyView("rtmp://foobar.org:3321/5678")
        }
    }
}

private struct SrtHelpView: View {
    var body: some View {
        Section("OBS Media Source (SRT)") {
            UrlCopyView("srt://134.20.342.12:5000")
        }
        Section("BELABOX cloud SRTLA") {
            UrlCopyView("srtla://uk.srt.belabox.net:5000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3")
        }
        Section("BELABOX cloud SRT") {
            UrlCopyView("srt://uk.srt.belabox.net:4000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3")
        }
        Section("SRTLA server") {
            UrlCopyView("srtla://foobar.org:4432")
        }
        Section("SRT Live Server (SLS)") {
            UrlCopyView("srt://120.12.32.12:4000?streamid=publish/live/feed")
        }
    }
}

private struct WhipHelpView: View {
    var body: some View {
        Section("MediaMTX WHIP") {
            UrlCopyView("whip://120.12.32.12:8889/mystream/whip")
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
    let showWhipHelp: Bool
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
                    .disabled(stream.enabled && model.isLive)
            } footer: {
                if let error {
                    FormFieldError(error: error)
                }
                Text("Do not share your URL with anyone or they can hijack your channel!")
                    .bold()
            }
            Section {
                TextButtonView("Examples") {
                    presentingHelp = true
                }
                .sheet(isPresented: $presentingHelp) {
                    NavigationView {
                        Form {
                            RtmpHelpView(stream: stream)
                            if showSrtHelp {
                                SrtHelpView()
                            }
                            if showWhipHelp {
                                WhipHelpView()
                            }
                        }
                        .navigationTitle("Examples")
                        .toolbar {
                            CloseToolbar(presenting: $presentingHelp)
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
                        showWhipHelp: true,
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
                        showWhipHelp: false,
                        value: destination.url)
    }
}
