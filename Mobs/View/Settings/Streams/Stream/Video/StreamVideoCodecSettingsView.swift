import SwiftUI

struct StreamVideoCodecSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(codecs, id: \.self) { codec in
                        Text(codec)
                    }
                }
                .onChange(of: selection) { codec in
                    stream.codec = SettingsStreamCodec(rawValue: codec)!
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Codec")
    }
}
