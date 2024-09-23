import Foundation
import SwiftUI

struct QuickButtonMicView: View {
    @EnvironmentObject var model: Model
    @State var selectedMic: Mic

    var body: some View {
        Form {
            Section {
                Picker("", selection: Binding(get: {
                    model.currentMic
                }, set: { mic, _ in
                    selectedMic = mic
                })) {
                    ForEach(model.listMics()) { mic in
                        Text(mic.name).tag(mic)
                    }
                }
                .onChange(of: selectedMic) { mic in
                    model.selectMicById(id: mic.id)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Mic")
    }
}
