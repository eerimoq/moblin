import SwiftUI

struct StreamVideoCodecSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    private var stream: SettingsStream
    @State private var selection: String

    init(model: Model, stream: SettingsStream, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
        selection = stream.codec.rawValue
    }

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
        .toolbar {
            toolbar
        }
    }
}
