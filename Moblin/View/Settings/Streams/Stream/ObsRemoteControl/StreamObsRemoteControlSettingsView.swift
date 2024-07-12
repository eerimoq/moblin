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
        model.store()
        if stream.enabled {
            model.obsWebSocketUrlUpdated()
        }
    }

    func submitWebSocketPassword(value: String) {
        stream.obsWebSocketPassword = value
        model.store()
        if stream.enabled {
            model.obsWebSocketPasswordUpdated()
        }
    }

    func submitSourceName(value: String) {
        stream.obsSourceName = value
        model.store()
    }

    func submitBrbScene(value: String) {
        stream.obsBrbScene = value
        model.store()
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
                    title: String(localized: "BRB scene"),
                    value: stream.obsBrbScene!,
                    onSubmit: submitBrbScene,
                    capitalize: true
                )
            } footer: {
                Text("""
                Moblin will periodically try to switch to this OBS scene if the stream is \
                likely broken.
                """)
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
            Section {
                Toggle("Auto start streaming when going live", isOn: Binding(get: {
                    stream.obsAutoStartRecording!
                }, set: { value in
                    stream.obsAutoStartRecording = value
                    model.store()
                }))
                Toggle("Auto stop streaming when ending stream", isOn: Binding(get: {
                    stream.obsAutoStopRecording!
                }, set: { value in
                    stream.obsAutoStopRecording = value
                    model.store()
                }))
            }
            footer: {
                Text("OBS will automatically start or stop stream according to the Moblin stream status.")
            }
            Section {
                Toggle("Auto start recording when going live", isOn: Binding(get: {
                    stream.obsAutoStartStream!
                }, set: { value in
                    stream.obsAutoStartStream = value
                    model.store()
                }))
                Toggle("Auto stop recording when ending stream", isOn: Binding(get: {
                    stream.obsAutoStopStream!
                }, set: { value in
                    stream.obsAutoStopStream = value
                    model.store()
                }))
            }
            footer: {
                Text("OBS will automatically start or stop recording according to the Moblin stream status.")
            }
        }
        .navigationTitle("OBS remote control")
        .toolbar {
            SettingsToolbar()
        }
    }
}
