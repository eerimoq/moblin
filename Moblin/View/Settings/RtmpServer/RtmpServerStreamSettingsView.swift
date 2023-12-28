import SwiftUI

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var stream: SettingsRtmpServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.store()
        model.objectWillChange.send()
    }

    private func submitStreamKey(value: String) {
        stream.streamKey = value.trim()
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    private func streamUrl(placeholder: String = "") -> String {
        if stream.streamKey.isEmpty {
            return placeholder
        } else {
            return rtmpStreamUrl(address: rtmpAddressPlaceholder, port: port, streamKey: stream.streamKey)
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Name"),
                    value: stream.name,
                    onSubmit: submitName
                )) {
                    TextItemView(name: String(localized: "Name"), value: stream.name)
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Stream key"),
                    value: stream.streamKey,
                    onSubmit: submitStreamKey
                )) {
                    TextItemView(name: String(localized: "Stream key"), value: stream.streamKey)
                }
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                HStack {
                    Text(streamUrl(placeholder: "Stream key missing"))
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = streamUrl()
                        model.makeToast(title: "Copied to clipboard")
                    }, label: {
                        Image(systemName: "doc.on.doc")
                    })
                    .disabled(streamUrl().isEmpty)
                }
            } header: {
                Text("Publish URL")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Enter this URL into the RTMP publisher device to send video to this stream.")
                    Text("")
                    Text("Replace \(rtmpAddressPlaceholder) with your phones IP address.")
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
