import SwiftUI

private struct SpeakerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers
    @ObservedObject var speaker: SettingsAutoCameraSpeaker

    private func getSceneName(sceneId: UUID?) -> String {
        if let sceneId, let sceneName = model.getSceneName(id: sceneId) {
            return sceneName
        }
        return String(localized: "-- None --")
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(
                        name: $speaker.name,
                        existingNames: autoCameraSwitchers.switchers
                            .flatMap(\.speakers)
                    )
                }
                Section {
                    Picker(selection: $speaker.sceneId) {
                        Text("-- None --")
                            .tag(nil as UUID?)
                        ForEach(model.database.scenes) { scene in
                            SceneNameView(scene: scene)
                                .tag(scene.id as UUID?)
                        }
                    } label: {
                        Text("Camera scene")
                    }
                }
                Section {
                    HStack {
                        Text("Mic weight")
                        Slider(value: $speaker.micWeight, in: 0.1 ... 2.0, step: 0.1)
                        Text(String(format: "%.1f", speaker.micWeight))
                    }
                } footer: {
                    Text("Adjusts the relative sensitivity for this speaker's microphones.")
                }
            }
            .navigationTitle("Speaker")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(speaker.name)
                Spacer()
                GrayTextView(text: getSceneName(sceneId: speaker.sceneId))
            }
        }
    }
}

private struct SpeakersSettingsView: View {
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers
    @ObservedObject var switcher: SettingsAutoCameraSwitcher

    var body: some View {
        Section {
            ForEach(switcher.speakers) { speaker in
                SpeakerSettingsView(
                    autoCameraSwitchers: autoCameraSwitchers,
                    speaker: speaker
                )
            }
            .onMove { froms, to in
                switcher.speakers.move(fromOffsets: froms, toOffset: to)
            }
            .onDelete { offsets in
                switcher.speakers.remove(atOffsets: offsets)
            }
            AddButtonView {
                let speaker = SettingsAutoCameraSpeaker()
                speaker.name = makeUniqueName(
                    name: SettingsAutoCameraSpeaker.baseName,
                    existingNames: switcher.speakers
                )
                switcher.speakers.append(speaker)
            }
        } header: {
            Text("Speakers")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a speaker"))
        }
    }
}

private struct AutoCameraSwitcherDetailView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers
    @ObservedObject var switcher: SettingsAutoCameraSwitcher

    private func getSceneName(sceneId: UUID?) -> String {
        if let sceneId, let sceneName = model.getSceneName(id: sceneId) {
            return sceneName
        }
        return String(localized: "-- None --")
    }

    var body: some View {
        Form {
            Section {
                NameEditView(
                    name: $switcher.name,
                    existingNames: autoCameraSwitchers.switchers
                )
            }
            Section {
                Toggle("Enabled", isOn: $switcher.enabled)
            }
            SpeakersSettingsView(
                autoCameraSwitchers: autoCameraSwitchers,
                switcher: switcher
            )
            Section {
                Picker(selection: $switcher.wideShotSceneId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(model.database.scenes) { scene in
                        SceneNameView(scene: scene)
                            .tag(scene.id as UUID?)
                    }
                } label: {
                    Text("Wide shot scene")
                }
            } header: {
                Text("Wide shot")
            }
            Section {
                HStack {
                    Text("Sensitivity")
                    Slider(value: $switcher.sensitivity, in: 0.0 ... 1.0, step: 0.05)
                    Text(String(format: "%.0f%%", switcher.sensitivity * 100))
                }
                HStack {
                    Text("Noise floor")
                    Slider(value: $switcher.noiseFloorDb, in: -80.0 ... -20.0, step: 1.0)
                    Text(String(format: "%.0f dB", switcher.noiseFloorDb))
                }
                HStack {
                    Text("Hysteresis")
                    Slider(value: $switcher.hysteresisDb, in: 0.0 ... 10.0, step: 0.5)
                    Text(String(format: "%.1f dB", switcher.hysteresisDb))
                }
                HStack {
                    Text("Smoothing")
                    Slider(value: $switcher.smoothingFactor, in: 0.05 ... 0.9, step: 0.05)
                    Text(String(format: "%.2f", switcher.smoothingFactor))
                }
            } header: {
                Text("Audio detection")
            }
            Section {
                Picker("Switch cooldown", selection: $switcher.switchCooldownMs) {
                    ForEach([500, 1000, 1500, 2000, 3000, 5000], id: \.self) {
                        Text("\($0) ms")
                    }
                }
                Picker("Min shot duration", selection: $switcher.minShotDurationMs) {
                    ForEach([500, 1000, 1500, 2000, 3000, 5000], id: \.self) {
                        Text("\($0) ms")
                    }
                }
                Picker("Prediction buffer", selection: $switcher.predictionBufferMs) {
                    ForEach([100, 150, 200, 250, 300], id: \.self) {
                        Text("\($0) ms")
                    }
                }
            } header: {
                Text("Timing")
            }
            Section {
                Picker("Wide shot interval", selection: $switcher.wideShotIntervalSeconds) {
                    ForEach([10, 15, 20, 30, 45, 60], id: \.self) {
                        Text("\($0)s")
                    }
                }
                Picker("Max speaker shot", selection: $switcher.maxSpeakerShotDurationSeconds) {
                    ForEach([10, 15, 20, 30, 45, 60], id: \.self) {
                        Text("\($0)s")
                    }
                }
            } header: {
                Text("Wide shot timing")
            }
            Section {
                Picker("Activity level", selection: $switcher.activityLevel) {
                    ForEach(SettingsAutoCameraActivityLevel.allCases, id: \.self) {
                        Text($0.displayName)
                    }
                }
            } header: {
                Text("Behavior")
            }
        }
        .navigationTitle("Auto camera switcher")
    }
}

private struct AutoCameraSwitcherItemView: View {
    @ObservedObject var switcher: SettingsAutoCameraSwitcher

    var body: some View {
        Text(switcher.name)
            .tag(switcher.id as UUID?)
    }
}

struct AutoCameraSwitchersSelectView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoCameraSwitcher: AutoCameraSwitcherProvider
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers

    var body: some View {
        Section {
            Picker("Current", selection: $autoCameraSwitcher.currentSwitcherId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(autoCameraSwitchers.switchers) {
                    AutoCameraSwitcherItemView(switcher: $0)
                }
            }
            .onChange(of: autoCameraSwitcher.currentSwitcherId) {
                model.setAutoCameraSwitcher(id: $0)
            }
        }
    }
}

struct AutoCameraSwitchersView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers
    let showSelector: Bool

    var body: some View {
        Form {
            if showSelector {
                AutoCameraSwitchersSelectView(
                    autoCameraSwitcher: model.autoCameraSwitcher,
                    autoCameraSwitchers: autoCameraSwitchers
                )
            }
            Section {
                ForEach(autoCameraSwitchers.switchers) { switcher in
                    NavigationLink {
                        AutoCameraSwitcherDetailView(
                            autoCameraSwitchers: autoCameraSwitchers,
                            switcher: switcher
                        )
                    } label: {
                        HStack {
                            DraggableItemPrefixView()
                            Text(switcher.name)
                            Spacer()
                        }
                    }
                }
                .onMove { froms, to in
                    autoCameraSwitchers.switchers.move(fromOffsets: froms, toOffset: to)
                }
                .onDelete { offsets in
                    model.deleteAutoCameraSwitchers(offsets: offsets)
                }
                CreateButtonView {
                    let switcher = SettingsAutoCameraSwitcher()
                    switcher.name = makeUniqueName(
                        name: SettingsAutoCameraSwitcher.baseName,
                        existingNames: autoCameraSwitchers.switchers
                    )
                    autoCameraSwitchers.switchers.append(switcher)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an auto camera switcher"))
            }
        }
        .navigationTitle("Auto camera switchers")
    }
}

struct AutoCameraSwitchersSettingsView: View {
    @ObservedObject var autoCameraSwitchers: SettingsAutoCameraSwitchers
    let showSelector: Bool

    var body: some View {
        NavigationLink {
            AutoCameraSwitchersView(
                autoCameraSwitchers: autoCameraSwitchers,
                showSelector: showSelector
            )
        } label: {
            Text("Auto camera switchers")
        }
    }
}
