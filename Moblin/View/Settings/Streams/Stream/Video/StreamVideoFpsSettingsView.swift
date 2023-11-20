import SwiftUI

struct StreamVideoFpsSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: Int

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
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("FPS")
        .toolbar {
            SettingsToolbar()
        }
    }
}
