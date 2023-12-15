import SwiftUI

struct StreamAudioSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private func onBitrateChange(bitrate: String) {
        guard let bitrate = Int(bitrate) else {
            model.makeErrorToast(title: "Bitrate must be a number")
            return
        }
        guard bitrate >= 32 && bitrate <= 320 else {
            model.makeErrorToast(title: "Bitrate not 32 - 320 kbps")
            return
        }
        stream.audioBitrate = bitrate * 1000
        model.store()
        if model.stream.enabled {
            model.setAudioStreamBitrate(stream: stream)
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Bitrate"),
                    value: String(stream.audioBitrate! / 1000),
                    onSubmit: onBitrateChange,
                    footer: Text("Audio bitrate as 32 - 320 kbps. Only AAC codec is supported.")
                )) {
                    TextItemView(
                        name: String(localized: "Bitrate"),
                        value: String(stream.audioBitrate! / 1000)
                    )
                }
            }
        }
        .navigationTitle("Audio")
        .toolbar {
            SettingsToolbar()
        }
    }
}
