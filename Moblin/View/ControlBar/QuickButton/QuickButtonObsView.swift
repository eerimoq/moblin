import AVFoundation
import SwiftUI

private struct ObsStartStopStreamingView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingStartStreamingConfirm: Bool = false
    @State private var isPresentingStopStreamingConfirm: Bool = false

    var body: some View {
        if model.obsStreamingState == .stopped {
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresentingStartStreamingConfirm = true
                    }, label: {
                        Text("Start streaming")
                    })
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
        } else if model.obsStreamingState == .starting {
            Section {
                HStack {
                    Spacer()
                    Text("Starting...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        } else if model.obsStreamingState == .started {
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresentingStopStreamingConfirm = true
                    }, label: {
                        Text("Stop streaming")
                    })
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
        } else if model.obsStreamingState == .stopping {
            Section {
                HStack {
                    Spacer()
                    Text("Stopping...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        } else {
            Section {
                HStack {
                    Spacer()
                    Text("Unknown streaming state.")
                    Spacer()
                }
            }
        }
    }
}

private struct ObsStartStopRecordingView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingStartRecordingConfirm: Bool = false
    @State private var isPresentingStopRecordingConfirm: Bool = false

    var body: some View {
        if model.obsRecordingState == .stopped {
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresentingStartRecordingConfirm = true
                    }, label: {
                        Text("Start recording")
                    })
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
        } else if model.obsRecordingState == .starting {
            Section {
                HStack {
                    Spacer()
                    Text("Starting...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        } else if model.obsRecordingState == .started {
            Section {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresentingStopRecordingConfirm = true
                    }, label: {
                        Text("Stop recording")
                    })
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
        } else if model.obsRecordingState == .stopping {
            Section {
                HStack {
                    Spacer()
                    Text("Stopping...")
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .listRowBackground(Color.gray)
        } else {
            Section {
                HStack {
                    Spacer()
                    Text("Unknown recording state.")
                    Spacer()
                }
            }
        }
    }
}

struct QuickButtonObsView: View {
    @EnvironmentObject var model: Model

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
                ObsStartStopStreamingView()
                ObsStartStopRecordingView()
                Section {
                    Picker("", selection: $model.obsCurrentScenePicker) {
                        ForEach(model.obsScenes, id: \.self) { scene in
                            Text(scene)
                        }
                    }
                    .onChange(of: model.obsCurrentScenePicker) { _ in
                        guard model.obsCurrentScene != model.obsCurrentScenePicker else {
                            return
                        }
                        model.setObsScene(name: model.obsCurrentScenePicker)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Scenes")
                }
                Section {
                    ForEach(model.obsSceneInputs) { input in
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
                Section {
                    if let image = model.obsScreenshot {
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
                if !model.stream.obsSourceName!.isEmpty {
                    if !model.obsFixOngoing {
                        Section {
                            HStack {
                                Spacer()
                                Button(action: {
                                    model.obsFixStream()
                                }, label: {
                                    Text("Fix \(model.stream.obsSourceName!) source")
                                })
                                Spacer()
                            }
                        } footer: {
                            Text("""
                            Restarts the \(model.stream.obsSourceName!) source to hopefully fix \
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
                            Restarts the \(model.stream.obsSourceName!) source to hopefully fix \
                            audio and video issues.
                            """)
                        }
                        .listRowBackground(Color.gray)
                    }
                    Section {
                        ValueEditView(
                            title: "Delay",
                            value: "\(model.obsAudioDelay)",
                            minimum: Double(obsMinimumAudioDelay),
                            maximum: Double(min(obsMaximumAudioDelay, 9999)),
                            onSubmit: submitAudioDelay,
                            increment: 10,
                            unit: "ms"
                        )
                    } header: {
                        Text("\(model.stream.obsSourceName!) source audio sync")
                    }
                    Section {
                        if model.isLive {
                            if !model.obsAudioVolume.isEmpty {
                                Text(model.obsAudioVolume)
                            } else {
                                Text("No audio levels received yet.")
                            }
                        } else {
                            Text("Go live to see audio levels.")
                        }
                    } header: {
                        Text("\(model.stream.obsSourceName!) source audio levels")
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
