import Foundation
import SwiftUI

private struct QuickButtonMicMicView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic
    @ObservedObject var modelMic: Mic

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            Image(systemName: mic.connected ? "cable.connector" : "cable.connector.slash")
            Text(mic.name)
                .lineLimit(1)
            Spacer()
            Image(systemName: modelMic.isSelected(mic: mic) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(modelMic.isSelected(mic: mic) ? .blue : .gray)
                .bold()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.updateMicsListAsync {
                if mic.connected {
                    model.manualToggleMicById(id: mic.id)
                }
            }
        }
    }
}

struct QuickButtonMicView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics
    @ObservedObject var modelMic: Mic

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(mics.mics) { mic in
                        QuickButtonMicMicView(model: model, mic: mic, modelMic: modelMic)
                    }
                    .onMove { froms, to in
                        mics.mics.move(fromOffsets: froms, toOffset: to)
                    }
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Select one or more mics to mix together.")
                    Text("")
                    Text("Highest priority mic at the top of the list.")
                }
            }
            if false {
                Section {
                    Toggle("Auto switch", isOn: $mics.autoSwitch)
                } footer: {
                    Text("Automatically switch to highest priority mic when plugged in.")
                }
            }
        }
        .onAppear {
            model.updateMicsListAsync()
        }
        .navigationTitle("Mic")
    }
}
