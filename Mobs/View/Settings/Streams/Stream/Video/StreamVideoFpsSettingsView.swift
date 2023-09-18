import SwiftUI

struct StreamVideoFpsSettingsView: View {
    @ObservedObject var model: Model
    private var stream: SettingsStream
    @State private var selection: Int

    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        selection = stream.fps
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(fpss, id: \.self) { fps in
                        Text(String(fps))
                    }
                }
                .onChange(of: selection) { fps in
                    stream.fps = fps
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("FPS")
    }
}
