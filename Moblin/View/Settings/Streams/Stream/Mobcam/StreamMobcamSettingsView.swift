import SwiftUI

struct StreamMobcamSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                TextItemLocalizedView(name: "Port", value: String(stream.mobcamPort()))
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Connect this device to a computer with a USB cable and run the Moblin Mobcam host \
                    tool on the computer to receive the stream. The computer connects to the port \
                    above over the cable.
                    """)
                    Text("")
                    Text("Change the port by editing the URL.")
                }
            }
        }
        .navigationTitle("Mobcam")
    }
}
