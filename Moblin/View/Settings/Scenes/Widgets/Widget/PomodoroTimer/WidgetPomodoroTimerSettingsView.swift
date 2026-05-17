import SwiftUI

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
            Picker("Width scale factor", selection: $pomodoroTimer.widthScaleFactor) {
                ForEach([1.0, 2.0, 3.0, 4.0, 5.0], id: \.self) {
                    Text("\(Int($0))x")
                }
            }
            .onChange(of: pomodoroTimer.widthScaleFactor) { _ in
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
