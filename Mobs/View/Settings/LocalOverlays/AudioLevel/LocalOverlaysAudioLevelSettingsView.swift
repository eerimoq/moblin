import SwiftUI

let meterTypes = ["Bar", "Decibel"]

struct LocalOverlaysAudioLevelSettingsView: View {
    @EnvironmentObject var model: Model
    @State var meterType: String

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
    }
}
