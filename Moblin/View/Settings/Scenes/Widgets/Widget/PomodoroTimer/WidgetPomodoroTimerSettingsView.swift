import AVFAudio
import SwiftUI

private func getPomodoroSoundName(model: Model, soundId: UUID?) -> String {
    guard let soundId else {
        return String(localized: "None")
    }
    return model.getAllAlertSounds().first(where: { $0.id == soundId })?.name ?? String(localized: "None")
}

private struct PomodoroSoundSelectorView: View {
    @EnvironmentObject var model: Model
    @Binding var soundId: UUID?
    @State private var previewPlayer: AudioPlayer?

    var body: some View {
        Form {
            Section {
                Picker("", selection: $soundId) {
                    ForEach(model.getAllAlertSounds()) { sound in
                        HStack {
                            Text(sound.name)
                            Spacer()
                            Button {
                                guard let url = model.getAlertSoundUrl(soundId: sound.id) else {
                                    return
                                }
                                previewPlayer = try? AudioPlayer(contentsOf: url)
                                previewPlayer?.play()
                            } label: {
                                Image(systemName: "play.fill")
                            }
                        }
                        .tag(sound.id as UUID?)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .onDisappear {
            previewPlayer = nil
        }
        .navigationTitle("Sound")
    }
}

struct WidgetPomodoroTimerQuickButtonControlsView: View {
    let model: Model
    @ObservedObject var pomodoroTimer: SettingsWidgetPomodoroTimer

    var body: some View {
        HStack(spacing: 13) {
            Spacer()
            Button {
                pomodoroTimer.advancePhase()
            } label: {
                Image(systemName: "forward.end")
                    .font(.title)
            }
            Button {
                pomodoroTimer.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title)
            }
            Button {
                if pomodoroTimer.isRunning {
                    pomodoroTimer.pause()
                } else {
                    pomodoroTimer.start()
                }
            } label: {
                Image(systemName: pomodoroTimer.isRunning ? "stop" : "play")
                    .font(.title)
                    .frame(width: 35)
            }
        }
        .buttonStyle(.borderless)
    }
}

struct WidgetPomodoroTimerSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var pomodoroTimer: SettingsWidgetPomodoroTimer

    var body: some View {
        Section {
            if pomodoroTimer.isRunning {
                TextButtonView("Pause") {
                    pomodoroTimer.pause()
                }
            } else {
                TextButtonView("Start") {
                    pomodoroTimer.start()
                }
            }
        }
        Section {
            TextButtonView("Reset") {
                pomodoroTimer.reset()
            }
            .tint(.red)
        }
        Section {
            Picker("Focus", selection: $pomodoroTimer.focusDuration) {
                ForEach([1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) {
                    Text("\($0) min")
                }
            }
            .onChange(of: pomodoroTimer.focusDuration) { _ in
                if pomodoroTimer.phase == .focus, !pomodoroTimer.isRunning {
                    pomodoroTimer.secondsRemaining = pomodoroTimer.focusDuration * 60
                }
            }
            Picker("Break", selection: $pomodoroTimer.breakDuration) {
                ForEach([1, 2, 3, 5, 7, 10, 15, 20, 30], id: \.self) {
                    Text("\($0) min")
                }
            }
            .onChange(of: pomodoroTimer.breakDuration) { _ in
                if pomodoroTimer.phase == .shortBreak, !pomodoroTimer.isRunning {
                    pomodoroTimer.secondsRemaining = pomodoroTimer.breakDuration * 60
                }
            }
        } header: {
            Text("Durations")
        }
        Section {
            Picker("Focus", selection: $pomodoroTimer.focusIcon) {
                ForEach(PomodoroFocusIcon.allCases, id: \.self) { icon in
                    HStack {
                        Image(systemName: icon.rawValue)
                        Text(icon.toString())
                    }
                }
            }
            Picker("Break", selection: $pomodoroTimer.breakIcon) {
                ForEach(PomodoroBreakIcon.allCases, id: \.self) { icon in
                    HStack {
                        Image(systemName: icon.rawValue)
                        Text(icon.toString())
                    }
                }
            }
        } header: {
            Text("Icons")
        }
        Section {
            HStack {
                Text("Width")
                Slider(value: $pomodoroTimer.width, in: 1 ... 5, step: 0.05)
            }
        }
        Section {
            ColorPicker("Background", selection: $pomodoroTimer.backgroundColorColor, supportsOpacity: true)
                .onChange(of: pomodoroTimer.backgroundColorColor) { _ in
                    guard let color = pomodoroTimer.backgroundColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.backgroundColor = color
                }
            ColorPicker("Text", selection: $pomodoroTimer.foregroundColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.foregroundColorColor) { _ in
                    guard let color = pomodoroTimer.foregroundColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.foregroundColor = color
                }
            ColorPicker("Focus", selection: $pomodoroTimer.focusColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.focusColorColor) { _ in
                    guard let color = pomodoroTimer.focusColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.focusColor = color
                }
            ColorPicker("Break", selection: $pomodoroTimer.breakColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.breakColorColor) { _ in
                    guard let color = pomodoroTimer.breakColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.breakColor = color
                }
        } header: {
            Text("Colors")
        }
        Section {
            Toggle("Focus to break", isOn: $pomodoroTimer.focusToBreakSoundEnabled)
            if pomodoroTimer.focusToBreakSoundEnabled {
                NavigationLink {
                    PomodoroSoundSelectorView(soundId: $pomodoroTimer.focusToBreakSoundId)
                        .environmentObject(model)
                } label: {
                    TextValueView(
                        name: "Sound",
                        value: getPomodoroSoundName(model: model, soundId: pomodoroTimer.focusToBreakSoundId)
                    )
                }
            }
            Toggle("Break to focus", isOn: $pomodoroTimer.breakToFocusSoundEnabled)
            if pomodoroTimer.breakToFocusSoundEnabled {
                NavigationLink {
                    PomodoroSoundSelectorView(soundId: $pomodoroTimer.breakToFocusSoundId)
                        .environmentObject(model)
                } label: {
                    TextValueView(
                        name: "Sound",
                        value: getPomodoroSoundName(model: model, soundId: pomodoroTimer.breakToFocusSoundId)
                    )
                }
            }
        } header: {
            Text("Sounds")
        }
        Section {
            Toggle("Focus to break", isOn: $pomodoroTimer.sendFocusToBreakChatMessage)
            if pomodoroTimer.sendFocusToBreakChatMessage {
                TextEditNavigationView(
                    title: String(localized: "Message"),
                    value: pomodoroTimer.focusToBreakChatMessage,
                    onSubmit: { pomodoroTimer.focusToBreakChatMessage = $0 }
                )
            }
            Toggle("Break to focus", isOn: $pomodoroTimer.sendBreakToFocusChatMessage)
            if pomodoroTimer.sendBreakToFocusChatMessage {
                TextEditNavigationView(
                    title: String(localized: "Message"),
                    value: pomodoroTimer.breakToFocusChatMessage,
                    onSubmit: { pomodoroTimer.breakToFocusChatMessage = $0 }
                )
            }
        } header: {
            Text("Chat messages")
        }
    }
}
