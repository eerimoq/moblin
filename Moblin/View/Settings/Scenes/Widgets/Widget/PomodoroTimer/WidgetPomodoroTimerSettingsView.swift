import SwiftUI

struct WidgetPomodoroTimerQuickButtonControlsView: View {
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
    @ObservedObject var pomodoroTimer: SettingsWidgetPomodoroTimer

    var body: some View {
        Section {
            WidgetPomodoroTimerQuickButtonControlsView(pomodoroTimer: pomodoroTimer)
        } header: {
            Text("Controls")
        }
        Section {
            Picker("Focus", selection: $pomodoroTimer.focusDuration) {
                ForEach([1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120], id: \.self) {
                    Text("\($0) min")
                }
            }
            .onChange(of: pomodoroTimer.focusDuration) { _ in
                pomodoroTimer.focusDurationChanged()
            }
            Picker("Break", selection: $pomodoroTimer.breakDuration) {
                ForEach([1, 2, 3, 5, 7, 10, 15, 20, 25, 30], id: \.self) {
                    Text("\($0) min")
                }
            }
            .onChange(of: pomodoroTimer.breakDuration) { _ in
                pomodoroTimer.breakDurationChanged()
            }
        } header: {
            Text("Durations")
        }
        Section {
            TextEditNavigationView(
                title: String(localized: "Focus"),
                value: pomodoroTimer.focusName,
                onSubmit: { pomodoroTimer.focusName = $0 }
            )
            TextEditNavigationView(
                title: String(localized: "Break"),
                value: pomodoroTimer.breakName,
                onSubmit: { pomodoroTimer.breakName = $0 }
            )
        } header: {
            Text("Names")
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
                    .onChange(of: pomodoroTimer.width) { _ in
                        model.updateWidgetOutlines()
                    }
            }
        }
        Section {
            RgbColorPickerView(
                title: "Background",
                color: $pomodoroTimer.backgroundColorColor,
                opacity: true
            ) {
                pomodoroTimer.backgroundColor = $0
            }
            RgbColorPickerView(title: "Text", color: $pomodoroTimer.foregroundColorColor) {
                pomodoroTimer.foregroundColor = $0
            }
            RgbColorPickerView(title: "Focus", color: $pomodoroTimer.focusColorColor) {
                pomodoroTimer.focusColor = $0
            }
            RgbColorPickerView(title: "Break", color: $pomodoroTimer.breakColorColor) {
                pomodoroTimer.breakColor = $0
            }
        } header: {
            Text("Colors")
        }
        Section {
            SoundSelectorNavigationView(model: model,
                                        gallery: model.database.alertsMediaGallery,
                                        title: "Focus to break",
                                        soundId: $pomodoroTimer.focusToBreakSoundId)
            SoundSelectorNavigationView(model: model,
                                        gallery: model.database.alertsMediaGallery,
                                        title: "Break to focus",
                                        soundId: $pomodoroTimer.breakToFocusSoundId)
        } header: {
            Text("Sounds")
        }
        Section {
            TextEditNavigationView(
                title: String(localized: "Focus to break"),
                value: pomodoroTimer.focusToBreakChatMessage,
                onSubmit: { pomodoroTimer.focusToBreakChatMessage = $0 }
            )
            TextEditNavigationView(
                title: String(localized: "Break to focus"),
                value: pomodoroTimer.breakToFocusChatMessage,
                onSubmit: { pomodoroTimer.breakToFocusChatMessage = $0 }
            )
        } header: {
            Text("Chat messages")
        }
    }
}
