import SwiftUI

private struct InfoView: View {
    @EnvironmentObject var model: Model
    var icon: String
    var text: String
    var get: () -> Bool
    var set: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: iconWidth)
            Toggle(text, isOn: Binding(get: {
                get()
            }, set: { value in
                set(value)
                model.objectWillChange.send()
            }))
        }
    }
}

struct LocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model

    var show: SettingsShow {
        model.database.show
    }

    var body: some View {
        Form {
            Section("Top left") {
                InfoView(icon: "dot.radiowaves.left.and.right", text: String(localized: "Stream")) {
                    show.stream
                } set: { value in
                    show.stream = value
                }
                InfoView(icon: "camera", text: String(localized: "Camera")) {
                    show.cameras!
                } set: { value in
                    show.cameras = value
                }
                InfoView(icon: "music.mic", text: String(localized: "Mic")) {
                    show.microphone
                } set: { value in
                    show.microphone = value
                }
                InfoView(icon: "xserve", text: String(localized: "OBS remote control")) {
                    show.obsStatus!
                } set: { value in
                    show.obsStatus = value
                }
                InfoView(icon: "megaphone", text: String(localized: "Events (alerts)")) {
                    show.events!
                } set: { value in
                    show.events = value
                }
                InfoView(icon: "message", text: String(localized: "Chat")) {
                    show.chat
                } set: { value in
                    show.chat = value
                }
                InfoView(icon: "eye", text: String(localized: "Viewers")) {
                    show.viewers
                } set: { value in
                    show.viewers = value
                }
            }
            Section("Top right") {
                InfoView(icon: "waveform", text: String(localized: "Audio level")) {
                    show.audioLevel
                } set: { value in
                    show.audioLevel = value
                }
                InfoView(icon: "location", text: String(localized: "Location")) {
                    show.location!
                } set: { value in
                    show.location = value
                }
                InfoView(icon: "server.rack", text: String(localized: "RTMP server")) {
                    show.rtmpSpeed!
                } set: { value in
                    show.rtmpSpeed = value
                }
                InfoView(icon: "appletvremote.gen1", text: String(localized: "Remote control")) {
                    show.remoteControl!
                } set: { value in
                    show.remoteControl = value
                }
                InfoView(icon: "gamecontroller", text: String(localized: "Game controllers")) {
                    show.gameController!
                } set: { value in
                    show.gameController = value
                }
                InfoView(icon: "speedometer", text: String(localized: "Bitrate")) {
                    show.speed
                } set: { value in
                    show.speed = value
                }
                InfoView(icon: "deskclock", text: String(localized: "Uptime")) {
                    show.uptime
                } set: { value in
                    show.uptime = value
                }
                InfoView(icon: "globe", text: String(localized: "Browser widgets")) {
                    show.browserWidgets!
                } set: { value in
                    show.browserWidgets = value
                }
                InfoView(icon: "phone.connection", text: String(localized: "Bonding")) {
                    show.bonding!
                } set: { value in
                    show.bonding = value
                }
            }
            Section {
                Toggle("Zoom presets", isOn: Binding(get: {
                    show.zoomPresets
                }, set: { value in
                    show.zoomPresets = value
                }))
            } header: {
                Text("Bottom right")
            } footer: {
                Text("")
                Text("Local overlays do not appear on stream.")
            }
        }
        .navigationTitle("Local overlays")
        .toolbar {
            SettingsToolbar()
        }
    }
}
