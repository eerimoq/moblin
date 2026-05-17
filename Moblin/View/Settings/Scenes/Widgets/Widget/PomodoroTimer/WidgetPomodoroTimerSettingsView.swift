import SwiftUI

struct WidgetPomodoroTimerQuickButtonControlsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget

    private func updateEffect() {
        model.getPomodoroTimerEffect(id: widget.id)?.setSettings(settings: widget.pomodoroTimer)
    }

    var body: some View {
        if widget.pomodoroTimer.isRunning {
            Button {
                widget.pomodoroTimer.pause()
                updateEffect()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title)
            }
        } else {
            Button {
                widget.pomodoroTimer.start()
                updateEffect()
            } label: {
                Image(systemName: "play.fill")
                    .font(.title)
            }
        }
    }
}

struct WidgetPomodoroTimerSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var pomodoroTimer: SettingsWidgetPomodoroTimer

    private func updateEffect() {
        model.getPomodoroTimerEffect(id: widget.id)?.setSettings(settings: pomodoroTimer)
    }

    var body: some View {
        Section {
            if pomodoroTimer.isRunning {
                TextButtonView("Pause") {
                    pomodoroTimer.pause()
                    updateEffect()
                }
            } else {
                TextButtonView("Start") {
                    pomodoroTimer.start()
                    updateEffect()
                }
            }
        }
        Section {
            TextButtonView("Reset") {
                pomodoroTimer.reset()
                updateEffect()
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
                updateEffect()
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
                updateEffect()
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
                    .tag(icon)
                }
            }
            .onChange(of: pomodoroTimer.focusIcon) { _ in
                updateEffect()
            }
            Picker("Break", selection: $pomodoroTimer.breakIcon) {
                ForEach(PomodoroBreakIcon.allCases, id: \.self) { icon in
                    HStack {
                        Image(systemName: icon.rawValue)
                        Text(icon.toString())
                    }
                    .tag(icon)
                }
            }
            .onChange(of: pomodoroTimer.breakIcon) { _ in
                updateEffect()
            }
        } header: {
            Text("Icons")
        }
        Section {
            ColorPicker("Background", selection: $pomodoroTimer.backgroundColorColor, supportsOpacity: true)
                .onChange(of: pomodoroTimer.backgroundColorColor) { _ in
                    guard let color = pomodoroTimer.backgroundColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.backgroundColor = color
                    updateEffect()
                }
            ColorPicker("Text", selection: $pomodoroTimer.foregroundColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.foregroundColorColor) { _ in
                    guard let color = pomodoroTimer.foregroundColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.foregroundColor = color
                    updateEffect()
                }
            ColorPicker("Focus", selection: $pomodoroTimer.focusColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.focusColorColor) { _ in
                    guard let color = pomodoroTimer.focusColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.focusColor = color
                    updateEffect()
                }
            ColorPicker("Break", selection: $pomodoroTimer.breakColorColor, supportsOpacity: false)
                .onChange(of: pomodoroTimer.breakColorColor) { _ in
                    guard let color = pomodoroTimer.breakColorColor.toRgb() else {
                        return
                    }
                    pomodoroTimer.breakColor = color
                    updateEffect()
                }
        } header: {
            Text("Colors")
        }
    }
}
