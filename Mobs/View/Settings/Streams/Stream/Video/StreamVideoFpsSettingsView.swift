import SwiftUI

struct StreamVideoFpsSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    private var stream: SettingsStream
    @State private var selection: Int

    init(model: Model, stream: SettingsStream, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
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
        .toolbar {
            toolbar
        }
    }
}
