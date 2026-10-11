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
            if model.isMicMixable(mic: mic) {
                Image(systemName: mic.mixed ? "plus.circle.fill" : "plus.circle")
                    .foregroundStyle(.blue)
                    .onTapGesture {
                        model.setMicMixed(mic: mic, mixed: !mic.mixed)
                    }
            }
            Image(systemName: "checkmark")
                .foregroundStyle(mic == modelMic.current ? .blue : .clear)
                .bold()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mic.connected {
                model.manualSelectMicById(id: mic.id)
            }
        }
    }
}

private struct QuickButtonMicMixVolumeView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Image(systemName: "speaker.wave.1.fill")
                Slider(value: $mic.mixVolumeDb, in: -30 ... 12, step: 1)
                    .onChange(of: mic.mixVolumeDb) { _ in
                        model.updateMixedMics()
                    }
                Image(systemName: "speaker.wave.3.fill")
                Text("\(formatOneDecimal(mic.mixVolumeDb)) dB")
                    .frame(width: 65)
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
                            .deleteDisabled(mic == modelMic.current)
                            .contextMenuDeleteButton(disabled: mic == modelMic.current) {
                                mics.mics.removeAll { $0.id == mic.id }
                            }
                    }
                    .onDelete { offsets in
                        mics.mics.remove(atOffsets: offsets)
                    }
                    .onMove { froms, to in
                        mics.mics.move(fromOffsets: froms, toOffset: to)
                    }
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Highest priority mic at the top of the list.")
                    Text("")
                    let image = Image(systemName: "plus.circle")
                    Text("""
                    Tap a mic to select it. Tap \(image) to mix its audio into the \
                    selected mic.
                    """)
                    Text("")
                    Text("Only one built-in or external mic can be used at a time.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a mic"))
                }
            }
            if !modelMic.mixed.isEmpty {
                Section {
                    ForEach(modelMic.mixed) { mic in
                        QuickButtonMicMixVolumeView(model: model, mic: mic)
                    }
                } header: {
                    Text("Mix volume")
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
        .navigationTitle("Mic")
    }
}
