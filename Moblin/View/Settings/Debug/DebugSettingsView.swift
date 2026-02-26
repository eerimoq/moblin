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

    private func reloadLog() {
        log = model.log
    }

    var body: some View {
        Form {
            Section {
                TextButtonView("Log") {
                    presentingLog = true
                }
                .fullScreenCover(isPresented: $presentingLog) {
                    DebugLogSettingsView(model: model,
                                         debug: debug,
                                         log: $log,
                                         presentingLog: $presentingLog,
                                         reloadLog: reloadLog,
                                         clearLog: { model.clearLog() })
                        .task {
                            reloadLog()
                        }
                }
            }
            Section {
                Toggle("Debug logging", isOn: $debug.debugLogging)
                    .onChange(of: debug.debugLogging) { _ in
                        model.setDebugLogging(on: debug.debugLogging)
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
            } header: {
                Text("Experimental")
            }
            Section {
                Toggle("Vertical movement", isOn: $debug.cameraManMoveVertically)
                    .onChange(of: debug.cameraManMoveVertically) { _ in
                        model.cameraManEffect.setSettings(moveVertically: debug.cameraManMoveVertically,
                                                          speed: debug.cameraManSpeed)
                    }
                HStack {
                    Text("Speed")
                    Slider(value: $debug.cameraManSpeed, in: 0.2 ... 8) { _ in
                        model.cameraManEffect.setSettings(moveVertically: debug.cameraManMoveVertically,
                                                          speed: debug.cameraManSpeed)
                    }
                }
            } header: {
                Text("Camera man")
            }
        }
        .navigationTitle("Debug")
    }
}
