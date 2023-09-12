import SwiftUI

var fpss = [60, 30, 15, 5]

struct StreamVideoFpsSettingsView: View {
    @ObservedObject var model: Model
    private var stream: SettingsStream
    @State private var selection: Int
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
        self.selection = stream.fps
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
                    model.store()
                    if stream.enabled {
                        model.reloadStream()
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("FPS")
    }
}
