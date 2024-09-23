import SwiftUI

struct StreamObsRemoteControlSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitWebSocketUrl(value: String) {
        let url = cleanUrl(url: value)
        if let message = isValidWebSocketUrl(url: url) {
            model.makeErrorToast(title: message)
            return
        }
        stream.obsWebSocketUrl = url
        if stream.enabled {
            model.obsWebSocketUrlUpdated()
        }
    }

    func submitWebSocketPassword(value: String) {
        stream.obsWebSocketPassword = value
        if stream.enabled {
            model.obsWebSocketPasswordUpdated()
        }
    }

    func submitSourceName(value: String) {
        stream.obsSourceName = value
    }

    func submitBrbScene(value: String) {
        stream.obsBrbScene = value
    }

    func submitMainScene(value: String) {
        stream.obsMainScene = value
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: stream.obsWebSocketUrl!,
                    onSubmit: submitWebSocketUrl,
                    footers: [String(localized: "For example ws://232.32.45.332:4567.")],
                    keyboardType: .URL
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: stream.obsWebSocketPassword!,
                    onSubmit: submitWebSocketPassword,
                    sensitive: true
                )
            } header: {
                Text("WebSocket")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Main scene"),
                    value: stream.obsMainScene!,
                    onSubmit: submitMainScene,
                    capitalize: true
                )
                TextEditNavigationView(
                    title: String(localized: "BRB scene"),
                    value: stream.obsBrbScene!,
                    onSubmit: submitBrbScene,
                    capitalize: true
                )
            } footer: {
                Text("""
                Moblin will periodically try to switch to the BRB scene if the stream is \
                likely broken, and back to the main scene once everything seems to work again.
                """)
            }
            if model.database.showAllSettings! {
                Section {
                    Toggle("BRB scene when video source is broken", isOn: Binding(get: {
                        stream.obsBrbSceneVideoSourceBroken!
                    }, set: { value in
                        stream.obsBrbSceneVideoSourceBroken = value
                    }))
                    .disabled(stream.obsBrbScene!.isEmpty)
                } footer: {
                    Text("""
                    Moblin will switch to the BRB scene configured above when the current scene's \
                    SRT(LA) or RTMP video source is disconnected. Typically enable when using Moblin \
                    as SRT(LA) server at home, streaming to OBS on the same computer.
                    """)
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Source name"),
                    value: stream.obsSourceName!,
                    onSubmit: submitSourceName,
                    capitalize: true
                )
            } footer: {
                Text("The name of the Source in OBS that receives the stream from Moblin.")
            }
            if model.database.showAllSettings! {
                Section {
                    Toggle("Auto start streaming when going live", isOn: Binding(get: {
                        stream.obsAutoStartStream!
                    }, set: { value in
                        stream.obsAutoStartStream = value
                    }))
                    Toggle("Auto stop streaming when ending stream", isOn: Binding(get: {
                        stream.obsAutoStopStream!
                    }, set: { value in
                        stream.obsAutoStopStream = value
                    }))
                }
                Section {
                    Toggle("Auto start recording when going live", isOn: Binding(get: {
                        stream.obsAutoStartRecording!
                    }, set: { value in
                        stream.obsAutoStartRecording = value
                    }))
                    Toggle("Auto stop recording when ending stream", isOn: Binding(get: {
                        stream.obsAutoStopRecording!
                    }, set: { value in
                        stream.obsAutoStopRecording = value
                    }))
                }
            }
        }
        .navigationTitle("OBS remote control")
    }
}
