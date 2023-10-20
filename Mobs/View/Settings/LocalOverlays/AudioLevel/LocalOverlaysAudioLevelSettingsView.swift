import SwiftUI

let meterTypes = ["Bar", "Decibel"]

struct LocalOverlaysAudioLevelSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    @State var meterType: String

    init(model: Model, toolbar: Toolbar) {
        self.model = model
        self.toolbar = toolbar
        if model.database.show.audioBar! {
            meterType = "Bar"
        } else {
            meterType = "Decibel"
        }
    }

    var body: some View {
        Form {
            Section("Type") {
                Picker("", selection: $meterType) {
                    ForEach(meterTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                .onChange(of: meterType) { type in
                    model.database.show.audioBar = type == "Bar"
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Audio level")
        .toolbar {
            toolbar
        }
    }
}
