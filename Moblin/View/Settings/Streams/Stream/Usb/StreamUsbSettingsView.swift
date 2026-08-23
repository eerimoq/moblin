import SwiftUI

struct StreamUsbSettingsView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                TextItemLocalizedView(name: "Port", value: String(stream.usbPort()))
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Connect this device to a computer with a USB cable and run the Moblin USB host \
                    tool on the computer to receive the stream. The computer connects to the port \
                    above over the cable.
                    """)
                    Text("")
                    Text("Change the port by editing the URL.")
                }
            }
        }
        .navigationTitle("USB")
    }
}
