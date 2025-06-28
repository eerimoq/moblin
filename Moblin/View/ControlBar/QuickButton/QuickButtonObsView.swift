import AVFoundation
import SwiftUI

private struct ObsStartStopStreamingView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs
    @State private var isPresentingStartStreamingConfirm = false
    @State private var isPresentingStopStreamingConfirm = false

    var body: some View {
        switch obsQuickButton.streamingState {
        case .stopped:
            Section {
                HStack {
                    Spacer()
                    Button {
                        isPresentingStartStreamingConfirm = true
                    } label: {
                        Text("Start streaming")
                    }
                    .confirmationDialog("", isPresented: $isPresentingStartStreamingConfirm) {
                        Button("Start") {
                            model.obsStartStream()
                        }
                    }
                    Spacer()
                }
            }
            .listRowBackground(RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(.blue, lineWidth: 2)))
        case .starting:
            Section {
                HStack {
                    Spacer()
                    Text("Starting...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        case .started:
            Section {
                HStack {
                    Spacer()
                    Button {
                        isPresentingStopStreamingConfirm = true
                    } label: {
                        Text("Stop streaming")
                    }
                    .confirmationDialog("", isPresented: $isPresentingStopStreamingConfirm) {
                        Button("Stop") {
                            model.obsStopStream()
                        }
                    }
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.blue)
        case .stopping:
            Section {
                HStack {
                    Spacer()
                    Text("Stopping...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        }
    }
}

private struct ObsStartStopRecordingView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs
    @State private var isPresentingStartRecordingConfirm: Bool = false
    @State private var isPresentingStopRecordingConfirm: Bool = false

    var body: some View {
        switch obsQuickButton.recordingState {
        case .stopped:
            Section {
                HStack {
                    Spacer()
                    Button {
                        isPresentingStartRecordingConfirm = true
                    } label: {
                        Text("Start recording")
                    }
                    .confirmationDialog("", isPresented: $isPresentingStartRecordingConfirm) {
                        Button("Start") {
                            model.obsStartRecording()
                        }
                    }
                    Spacer()
                }
            }
            .listRowBackground(RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(.blue, lineWidth: 2)))
        case .starting:
            Section {
                HStack {
                    Spacer()
                    Text("Starting...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        case .started:
            Section {
                HStack {
                    Spacer()
                    Button {
                        isPresentingStopRecordingConfirm = true
                    } label: {
                        Text("Stop recording")
                    }
                    .confirmationDialog("", isPresented: $isPresentingStopRecordingConfirm) {
                        Button("Stop") {
                            model.obsStopRecording()
                        }
                    }
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.blue)
        case .stopping:
            Section {
                HStack {
                    Spacer()
                    Text("Stopping...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        }
    }
}

struct QuickButtonObsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs

    private func submitAudioDelay(value: String) -> String {
        let offsetDouble = Double(value) ?? 0
        var offset = Int(offsetDouble)
        offset = offset.clamped(to: obsMinimumAudioDelay ... obsMaximumAudioDelay)
        model.setObsAudioDelay(offset: offset)
        return String(offset)
    }

    var body: some View {
        Form {
            if !model.isObsConnected() {
                Section {
                    Text("Unable to connect the OBS server. Retrying every 5 seconds.")
                }
            } else {
                ObsStartStopStreamingView(model: model, obsQuickButton: obsQuickButton)
                ObsStartStopRecordingView(model: model, obsQuickButton: obsQuickButton)
                Section {
                    if let image = obsQuickButton.obsScreenshot {
                        Image(image, scale: 1, label: Text(""))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(.black)
                    } else {
                        Text("No snapshot received yet.")
                    }
                } header: {
                    Text("Current scene snapshot")
                }
                Section {
                    Picker("", selection: $obsQuickButton.obsCurrentScenePicker) {
                        ForEach(obsQuickButton.obsScenes, id: \.self) { scene in
                            Text(scene)
                        }
                    }
                    .onChange(of: obsQuickButton.obsCurrentScenePicker) { _ in
                        guard obsQuickButton.obsCurrentScene != obsQuickButton.obsCurrentScenePicker else {
                            return
                        }
                        model.setObsScene(name: obsQuickButton.obsCurrentScenePicker)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Scenes")
                }
                Section {
                    ForEach(obsQuickButton.obsSceneInputs) { input in
                        if let muted = input.muted {
                            HStack {
                                Text(input.name)
                                Spacer()
                                Button {
                                    model.obsMuteAudio(inputName: input.name, muted: !muted)
                                } label: {
                                    if muted {
                                        Image(systemName: "microphone.slash")
                                            .foregroundColor(.red)
                                    } else {
                                        Image(systemName: "microphone")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Scene audio inputs")
                }
                if !model.stream.obsSourceName.isEmpty {
                    if !obsQuickButton.obsFixOngoing {
                        Section {
                            HStack {
                                Spacer()
                                Button {
                                    model.obsFixStream()
                                } label: {
                                    Text("Fix \(model.stream.obsSourceName) source")
                                }
                                Spacer()
                            }
                        } footer: {
                            Text("""
                            Restarts the \(model.stream.obsSourceName) source to hopefully fix \
                            audio and video issues.
                            """)
                        }
                        .listRowBackground(RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue, lineWidth: 2)))
                    } else {
                        Section {
                            HStack {
                                Spacer()
                                Text("Fixing...")
                                Spacer()
                            }
                            .foregroundColor(.white)
                        } footer: {
                            Text("""
                            Restarts the \(model.stream.obsSourceName) source to hopefully fix \
                            audio and video issues.
                            """)
                        }
                        .listRowBackground(Color.gray)
                    }
                    Section {
                        ValueEditView(
                            title: "Delay",
                            number: Float(obsQuickButton.obsAudioDelay),
                            value: "\(obsQuickButton.obsAudioDelay)",
                            minimum: Float(obsMinimumAudioDelay),
                            maximum: Float(min(obsMaximumAudioDelay, 9999)),
                            onSubmit: submitAudioDelay,
                            increment: 10,
                            unit: "ms"
                        )
                    } header: {
                        Text("\(model.stream.obsSourceName) source audio sync")
                    }
                    Section {
                        if model.isLive {
                            if !obsQuickButton.obsAudioVolume.isEmpty {
                                Text(obsQuickButton.obsAudioVolume)
                            } else {
                                Text("No audio levels received yet.")
                            }
                        } else {
                            Text("Go live to see audio levels.")
                        }
                    } header: {
                        Text("\(model.stream.obsSourceName) source audio levels")
                    }
                } else {
                    Text("""
                    Configure source name in \
                    Settings → Streams → \(model.stream.name) → OBS remote control for \
                    Fix button and more.
                    """)
                }
            }
        }
        .onAppear {
            model.listObsScenes(updateAudioInputs: true)
            model.startObsSourceScreenshot()
            model.startObsAudioVolume()
            model.updateObsAudioDelay()
        }
        .onDisappear {
            model.stopObsSourceScreenshot()
            model.stopObsAudioVolume()
        }
        .navigationTitle("OBS remote control")
    }
}
