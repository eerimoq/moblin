import Network
import SwiftUI

struct Insta360SettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var settings: SettingsInsta360
    @ObservedObject var ingests: Ingests

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Toggle("Enabled", isOn: $settings.enabled)
                        .onChange(of: settings.enabled) { _ in
                            model.reloadInsta360Client()
                        }
                    TextItemLocalizedView(name: "Status", value: ingests.insta360State.toString())
                    if settings.enabled {
                        TextButtonView("Reconnect") {
                            model.reloadInsta360Client()
                        }
                    }
                } footer: {
                    Text(
                        "Experimental GO Ultra support. Camera compatibility is not yet verified on hardware."
                    )
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Camera IP address"),
                        value: settings.host,
                        onChange: { value in
                            IPv4Address(value.trim()) == nil ? String(localized: "Invalid IP address") : nil
                        },
                        onSubmit: { value in
                            guard IPv4Address(value.trim()) != nil else {
                                return
                            }
                            settings.host = value.trim()
                            model.reloadInsta360Client()
                        },
                        footers: [String(localized: "192.168.42.1 by default.")],
                        keyboardType: .numbersAndPunctuation
                    )
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(settings.latency),
                        onChange: isValidIngestLatency,
                        onSubmit: { value in
                            guard let latency = Int32(value), latency >= 5 else {
                                return
                            }
                            settings.latency = latency
                            model.reloadInsta360Client()
                        },
                        footers: [String(localized: "5 or more milliseconds. 300 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
                Section {
                    Text("""
                    Connect this phone to the GO Ultra's Wi-Fi in Settings and close the Insta360 app. \
                    Enable the connection here, then select Insta360 GO Ultra as your scene's camera.
                    """)
                    Text("Video only. Select the phone or an external microphone for audio in Moblin.")
                    Text("Use cellular data or another network connection to send your live stream.")
                } header: {
                    Text("Setup")
                }
            }
            .navigationTitle("Insta360 GO Ultra")
        } label: {
            HStack {
                Text("Insta360 GO Ultra")
                Spacer()
                if settings.enabled {
                    GrayTextView(text: ingests.insta360State.toString())
                }
            }
        }
    }
}
