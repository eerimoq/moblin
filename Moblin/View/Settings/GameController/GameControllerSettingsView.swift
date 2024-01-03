import SwiftUI

struct GameControllerSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "dpad.left.fill")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "dpad.right.fill")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "dpad.up.fill")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "dpad.down.fill")
                    Spacer()
                    Text("")
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
                    Text("")
                }
                HStack {
                    Image(systemName: "y.circle")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "l.rectangle.roundedbottom")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "zl.rectangle.roundedtop")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "r.rectangle.roundedbottom")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "zr.rectangle.roundedtop")
                    Spacer()
                    Text("")
                }
                HStack {
                    Image(systemName: "plus.circle")
                    Spacer()
                    Text("")
                }
            }
        }
        .navigationTitle("Game controller")
        .toolbar {
            SettingsToolbar()
        }
    }
}
