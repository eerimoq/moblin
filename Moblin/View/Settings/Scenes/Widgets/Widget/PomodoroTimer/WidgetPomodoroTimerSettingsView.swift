import SwiftUI

struct WidgetPomodoroTimerSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var pomodoroTimer: SettingsWidgetPomodoroTimer

    private func updateEffect() {
        model.getPomodoroTimerEffect(id: widget.id)?.setSettings(settings: pomodoroTimer)
    }

    var body: some View {
        Section {
            HStack {
                Text("Work duration")
                Spacer()
                Stepper(
                    "\(pomodoroTimer.workDuration) min",
                    value: Binding(
                        get: { pomodoroTimer.workDuration },
                        set: { value in
                            pomodoroTimer.workDuration = max(1, value)
                            if pomodoroTimer.phase == .focus, !pomodoroTimer.isRunning {
                                pomodoroTimer.secondsRemaining = pomodoroTimer.workDuration * 60
                            }
                            updateEffect()
                        }
                    ),
                    in: 1 ... 120
                )
            }
            HStack {
                Text("Break duration")
                Spacer()
                Stepper(
                    "\(pomodoroTimer.breakDuration) min",
                    value: Binding(
                        get: { pomodoroTimer.breakDuration },
                        set: { value in
                            pomodoroTimer.breakDuration = max(1, value)
                            if pomodoroTimer.phase == .shortBreak, !pomodoroTimer.isRunning {
                                pomodoroTimer.secondsRemaining = pomodoroTimer.breakDuration * 60
                            }
                            updateEffect()
                        }
                    ),
                    in: 1 ... 60
                )
            }
        } header: {
            Text("Timer")
        }
        Section {
            HStack {
                Spacer()
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
                Spacer()
                TextButtonView("Reset") {
                    pomodoroTimer.reset()
                    updateEffect()
                }
                Spacer()
            }
            HStack {
                let phaseLabel = pomodoroTimer.phase == .focus
                    ? String(localized: "Focus")
                    : String(localized: "Break")
                let minutes = pomodoroTimer.secondsRemaining / 60
                let seconds = pomodoroTimer.secondsRemaining % 60
                Text("Phase: \(phaseLabel)")
                Spacer()
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.system(.body, design: .monospaced))
            }
        } header: {
            Text("Controls")
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
