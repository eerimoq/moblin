import SwiftUI

struct StreamVideoFpsSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: Int = 1

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
