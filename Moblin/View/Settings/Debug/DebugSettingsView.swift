import Collections
import SwiftUI
import WebKit

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug
    @State var presentingLog: Bool = false
    @State var log: Deque<LogEntry> = []

    private func changeLogLines(value: String) -> String? {
        guard let lines = Int(value) else {
            return String(localized: "Not a number")
        }
        guard lines >= 1 else {
            return String(localized: "Too small")
        }
        guard lines <= 100_000 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitLogLines(value: String) {
        guard let lines = Int(value) else {
            return
        }
        debug.maximumLogLines = lines
    }

    var body: some View {
        Form {
            Section {
                TextButtonView("Log") {
                    presentingLog = true
                }
                .fullScreenCover(isPresented: $presentingLog) {
                    DebugLogSettingsView(model: model,
                                         log: $log,
                                         presentingLog: $presentingLog,
                                         clearLog: { model.clearLog() })
                        .task {
                            log = model.log
                        }
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    debug.logLevel == .debug
                }, set: { value in
                    model.setDebugLogging(on: value)
                })) {
                    Text("Debug logging")
                }
                TextEditNavigationView(
                    title: "Maximum log lines",
                    value: String(debug.maximumLogLines),
                    onChange: changeLogLines,
                    onSubmit: submitLogLines
                )
                Toggle("Debug overlay", isOn: $debug.debugOverlay)
                    .onChange(of: debug.debugOverlay) { _ in
                        model.updateDebugOverlay()
                    }
            }
            Section {
                NavigationLink {
                    DebugVideoSettingsView(debug: debug)
                } label: {
                    Text("Video")
                }
                Toggle("Bitrate drop fix", isOn: $debug.bitrateDropFix)
                    .onChange(of: debug.bitrateDropFix) { _ in
                        model.setBitrateDropFix()
                    }
                HStack {
                    Text("Data rate limit")
                    Slider(
                        value: $debug.dataRateLimitFactor,
                        in: 1.2 ... 2.5,
                        step: 0.1,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setBitrateDropFix()
                        }
                    )
                    Text(formatOneDecimal(debug.dataRateLimitFactor))
                        .frame(width: 40)
                }
                Toggle("Relaxed bitrate decrement after scene switch", isOn: $debug.relaxedBitrate)
                Toggle("Twitch rewards", isOn: $debug.twitchRewards)
                Toggle("Reliable chat", isOn: $debug.reliableChat)
                VStack(alignment: .leading) {
                    Text("Builtin audio and video delay")
                    HStack {
                        Slider(
                            value: $debug.builtinAudioAndVideoDelay,
                            in: 0.0 ... 4.0,
                            step: 0.01
                        )
                        Text(formatTwoDecimals(debug.builtinAudioAndVideoDelay))
                            .frame(width: 40)
                    }
                }
                Toggle("New SRT", isOn: $debug.newSrt)
                    .onChange(of: debug.newSrt) { _ in
                        model.reloadStream()
                        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                    }

            } header: {
                Text("Experimental")
            }
        }
        .navigationTitle("Debug")
    }
}
