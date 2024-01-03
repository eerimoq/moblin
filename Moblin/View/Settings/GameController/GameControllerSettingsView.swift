import SwiftUI

private let actions = [
    "Record",
    "Stream",
    "Zoom in",
    "Zoom out",
    "Next zoom preset",
    "Previous zoom preset",
    "Next bitrate preset",
    "Previous bitrate preset",
    "Mute",
    "Torch",
    "Black screen",
    "Chat",
    "Pause chat",
    "Back scene",
    "Front scene",
    "DJI scene",
    "Main OBS scene",
    "Field OBS scene",
]

struct GameControllerSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "dpad.left.fill")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "dpad.right.fill")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "dpad.up.fill")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "dpad.down.fill")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "a.circle")
                    Spacer()
                    Text("Torch")
                }
                HStack {
                    Image(systemName: "b.circle")
                    Spacer()
                    Text("Mute")
                }
                HStack {
                    Image(systemName: "x.circle")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "y.circle")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "zl.rectangle.roundedtop")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "l.rectangle.roundedbottom")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "zr.rectangle.roundedtop")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "r.rectangle.roundedbottom")
                    Spacer()
                    Text("Unused")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Game controller")
        .toolbar {
            SettingsToolbar()
        }
    }
}
