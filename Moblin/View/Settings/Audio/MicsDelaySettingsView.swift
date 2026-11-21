import SwiftUI

private struct MicDelayView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        let range = makeMicDelayRange(audioMixer: model.database.debug.audioMixer)
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Slider(
                    value: Binding(get: { mic.delay.clamped(to: range) }, set: { mic.delay = $0 }),
                    in: range,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.updateMicDelay()
                    }
                )
                .onChange(of: mic.delay) { _ in
                    if !model.database.debug.audioMixer {
                        model.updateMicDelay()
                    }
                }
                Text("\(formatDelay(mic.delay.clamped(to: range))) s")
                    .frame(width: model.database.debug.audioMixer ? 70 : 60)
            }
        }
    }

    private func formatDelay(_ delay: Double) -> String {
        model.database.debug.audioMixer ? formatThreeDecimals(delay) : formatTwoDecimals(delay)
    }
}

private struct AudioSyncResultView: View {
    let result: AudioSyncResult
    let isAnchor: Bool
    let delay: Double?

    private func status() -> String {
        if let failure = result.failure {
            return failure
        }
        guard let arrival = result.arrival else {
            return ""
        }
        let quality = arrival.isGood ? String(localized: "Good") : String(localized: "Fair")
        if isAnchor {
            return String(localized: "Reference, \(quality)")
        }
        guard let delay else {
            return quality
        }
        let range = makeMicDelayRange(audioMixer: true)
        if range.contains(delay) {
            return String(localized: "Delay \(formatThreeDecimals(delay)) s, \(quality)")
        }
        return String(localized: "Needs \(formatThreeDecimals(delay)) s, outside the delay range")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(result.name)
                .lineLimit(1)
            Text(status())
                .font(.caption)
                .foregroundStyle(result.failure == nil ? .primary : .secondary)
        }
    }
}

private struct AudioSyncView: View {
    let model: Model
    @ObservedObject var audioSync: AudioSync

    var body: some View {
        let delays = model.audioSyncDelays()
        let detected = audioSync.results.filter { $0.arrival != nil }
        Section {
            Button {
                model.startAudioSync()
            } label: {
                HStack {
                    Spacer()
                    if audioSync.isListening {
                        ProgressView()
                    } else {
                        Text("Sync mixed mics")
                    }
                    Spacer()
                }
            }
            .disabled(audioSync.isListening)
            if let message = audioSync.message {
                Text(message)
            }
            if detected.count > 1 {
                Picker("Align to", selection: $audioSync.anchorId) {
                    ForEach(detected) { result in
                        Text(result.name)
                            .tag(result.id as String?)
                    }
                }
            }
            ForEach(audioSync.results) { result in
                AudioSyncResultView(
                    result: result,
                    isAnchor: result.id == audioSync.anchorId,
                    delay: delays[result.id]
                )
            }
            if detected.count > 1 {
                Button("Apply") {
                    model.applyAudioSync()
                }
            }
            if audioSync.undoDelays != nil {
                Button("Undo") {
                    model.undoAudioSync()
                }
            }
        } footer: {
            Text("""
            Plays a short sound on the speaker and measures when each mixed mic hears it. Hold the phone \
            still where you will stand. Viewers hear the sound if you are live.
            """)
        }
    }
}

struct MicsDelaySettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics

    var body: some View {
        Form {
            if model.database.debug.audioMixer {
                AudioSyncView(model: model, audioSync: model.audioSync)
            }
            Section {
                ForEach(mics.mics) { mic in
                    MicDelayView(model: model, mic: mic)
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("A positive delay makes the audio later, a negative delay earlier.")
                    Text("")
                    if model.database.debug.audioMixer {
                        Text("Use to synchronize audio and video, and mixed mics with each other.")
                    } else {
                        Text("Use to synchronize audio and video.")
                    }
                }
            }
        }
        .navigationTitle("Delays")
    }
}
