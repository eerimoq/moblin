import SwiftUI

private let rtmpExamples: [(LocalizedStringKey, String)] = [
    ("Twitch", "rtmp://arn03.contribute.live-video.net/app/live_123321_sdfopjfwjfpawjefpjawef"),
    ("YouTube", "rtmp://a.rtmp.youtube.com/live2/1bk2-0d03-9683-7k65-e4d3"),
    ("Facebook", "rtmps://live-api-s.facebook.com:443/rtmp/FB-11152522122511115-0-BctNCp9jzzz-AAA"),
    ("Kick", "rtmps://fa723fc1b171.global-contribute.live-video.net/sk_us-west-123hu43ui34hrkjh"),
    ("RTMP server", "rtmp://foobar.org:3321/app/5678"),
]

private let srtExamples: [(LocalizedStringKey, String)] = [
    ("OBS Media Source (SRT)", "srt://134.20.342.12:5000"),
    ("BELABOX cloud SRTLA", "srtla://uk.srt.belabox.net:5000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"),
    ("BELABOX cloud SRT", "srt://uk.srt.belabox.net:4000?streamid=NtlPUqXGFV4Bcm448wgc4fUuLdvDB3"),
    ("SRTLA server", "srtla://foobar.org:4432"),
    ("SRT Live Server (SLS)", "srt://120.12.32.12:4000?streamid=publish/live/feed"),
]

private let whipExamples: [(LocalizedStringKey, String)] = [
    ("MediaMTX WHIP", "whip://120.12.32.12:8889/mystream/whip"),
    ("MESHCAST.IO WHIP", "whips://de1.meshcast.io/whip/mystream"),
]

struct StreamUrlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        UrlSettingsView(model: model,
                        disabled: model.isLive || model.isRecording,
                        url: $stream.url,
                        value: stream.url,
                        placeholder: "srtla://foobar.org:4432",
                        allowedSchemes: nil,
                        examples: rtmpExamples + srtExamples + whipExamples,
                        onSubmitted: {
                            model.reloadStreamIfEnabled(stream: stream)
                        })
    }
}

struct StreamMultiStreamingUrlView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var destination: SettingsStreamMultiStreamingDestination

    var body: some View {
        UrlSettingsView(model: model,
                        disabled: model.isLive || model.isRecording,
                        url: $destination.url,
                        value: destination.url,
                        placeholder: "rtmp://foobar.org:3321/app/5678",
                        allowedSchemes: ["rtmp", "rtmps"],
                        examples: rtmpExamples,
                        onSubmitted: {
                            model.reloadStreamIfEnabled(stream: stream)
                        })
    }
}
