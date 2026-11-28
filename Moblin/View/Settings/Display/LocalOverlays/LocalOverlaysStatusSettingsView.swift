import SwiftUI

struct LocalOverlaysStatusSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var show: SettingsShow

    var body: some View {
        Form {
            if database.showAllSettings {
                Section("Top left") {
                    Label {
                        Toggle("Stream", isOn: $show.stream)
                    } icon: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                    Label {
                        Toggle("Camera", isOn: $show.cameras)
                    } icon: {
                        Image(systemName: "camera")
                    }
                    Label {
                        Toggle("Mic", isOn: $show.microphone)
                    } icon: {
                        Image(systemName: "music.mic")
                    }
                    Label {
                        Toggle("Zoom", isOn: $show.zoom)
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                    Label {
                        Toggle("OBS remote control", isOn: $show.obsStatus)
                    } icon: {
                        Image(systemName: "xserve")
                    }
                    Label {
                        Toggle("Events (alerts)", isOn: $show.events)
                    } icon: {
                        Image(systemName: "megaphone")
                    }
                    Label {
                        Toggle("Chat", isOn: $show.chat)
                    } icon: {
                        Image(systemName: "message")
                    }
                    Label {
                        Toggle("Viewers", isOn: $show.viewers)
                    } icon: {
                        Image(systemName: "eye")
                    }
                }
            }
            Section("Top right") {
                Label {
                    Toggle("Audio level", isOn: $show.audioLevel)
                } icon: {
                    Image(systemName: "waveform")
                }
                Label {
                    Toggle("Big audio level meter", isOn: $database.bigAudioLevelMeter)
                } icon: {
                    Image(systemName: "waveform")
                }
                if database.showAllSettings {
                    Label {
                        Toggle("System monitor", isOn: $show.systemMonitor)
                    } icon: {
                        Image(systemName: "cpu")
                    }
                    Label {
                        Toggle("Location", isOn: $show.location)
                    } icon: {
                        Image(systemName: "location")
                    }
                    Label {
                        Toggle("Ingests", isOn: $show.ingests)
                    } icon: {
                        Image(systemName: "server.rack")
                    }
                    Label {
                        Toggle("Moblink", isOn: $show.moblink)
                    } icon: {
                        Image(systemName: "app.connected.to.app.below.fill")
                    }
                    Label {
                        Toggle("Remote control", isOn: $show.remoteControl)
                    } icon: {
                        Image(systemName: "appletvremote.gen1")
                    }
                    if !isMac() {
                        Label {
                            Toggle("Moblin Cloud", isOn: $show.moblinCloud)
                        } icon: {
                            Image(systemName: "cloud")
                        }
                    }
                    Label {
                        Toggle("DJI devices", isOn: $show.djiDevices)
                    } icon: {
                        Image(systemName: "appletvremote.gen1")
                    }
                    Label {
                        Toggle("Game controllers", isOn: $show.gameController)
                    } icon: {
                        Image(systemName: "gamecontroller")
                    }
                    Label {
                        Toggle("Bitrate", isOn: $show.speed)
                    } icon: {
                        Image(systemName: "speedometer")
                    }
                    Label {
                        Toggle("Server bitrate", isOn: $show.serverBitrate)
                    } icon: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Label {
                        Toggle("Uptime", isOn: $show.uptime)
                    } icon: {
                        Image(systemName: "deskclock")
                    }
                    Label {
                        Toggle("Bonding", isOn: $show.bonding)
                    } icon: {
                        Image(systemName: "phone.connection")
                    }
                    Label {
                        Toggle("Bonding RTTs", isOn: $show.bondingRtts)
                    } icon: {
                        Image(systemName: "phone.connection")
                    }
                    Label {
                        Toggle("Cat printers", isOn: $show.catPrinter)
                    } icon: {
                        Image(systemName: "pawprint")
                    }
                    Label {
                        Toggle("Workout devices", isOn: $show.workoutDevice)
                    } icon: {
                        Image(systemName: "figure.walk.motion")
                    }
                }
            }
        }
        .navigationTitle("Status")
    }
}
