import SwiftUI

private struct TimePickerView: View {
    let model: Model
    let widget: SettingsWidget
    var clock: SettingsWidgetScoreboardClock
    @Binding var presenting: Bool
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    var body: some View {
        VStack {
            HStack {
                TimeComponentPickerView(title: "Minutes", range: 0 ..< 120, time: $minutes)
                TimeComponentPickerView(title: "Seconds", range: 0 ..< 60, time: $seconds)
            }
            .padding()
            HStack {
                TimeButtonView(text: "Set") {
                    model.handleUpdateGenericScoreboard(action: .init(
                        id: widget.id,
                        action: .setClock(minutes: minutes, seconds: seconds)
                    ))
                    presenting = false
                }
                TimeButtonView(text: "Cancel") {
                    presenting = false
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
        .onAppear {
            minutes = clock.minutes
            seconds = clock.seconds
        }
    }
}

private struct ScoreboardSetClockButtonView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var clock: SettingsWidgetScoreboardClock
    @State private var presenting: Bool = false

    var body: some View {
        Button {
            presenting = true
        } label: {
            Image(systemName: "clock")
                .font(.title)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $presenting) {
            TimePickerView(model: model,
                           widget: widget,
                           clock: clock,
                           presenting: $presenting)
        }
    }
}

private struct ScoreboardStartStopClockButtonView: View {
    @ObservedObject var clock: SettingsWidgetScoreboardClock

    var body: some View {
        Button {
            clock.isStopped.toggle()
        } label: {
            Image(systemName: clock.isStopped ? "play" : "stop")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardUndoButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .undo))
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardIncrementHomeButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .incrementHome))
        } label: {
            Image(systemName: "plus")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardIncrementAwayButtonView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Button {
            model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .incrementAway))
        } label: {
            Image(systemName: "plus")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

private struct ScoreboardResetScoreButtonView: View {
    let model: Model
    let widget: SettingsWidget
    @State private var presentingResetConfirimation = false

    var body: some View {
        Button {
            presentingResetConfirimation = true
        } label: {
            Image(systemName: "trash")
                .font(.title)
        }
        .buttonStyle(.borderless)
        .tint(.red)
        .confirmationDialog("", isPresented: $presentingResetConfirimation) {
            Button("Reset score", role: .destructive) {
                model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .reset))
            }
        }
    }
}

struct WidgetScoreboardGenericQuickButtonControlsView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        HStack(spacing: 13) {
            Spacer()
            VStack(spacing: 13) {
                ScoreboardStartStopClockButtonView(clock: widget.scoreboard.generic.clock)
                ScoreboardSetClockButtonView(model: model,
                                             widget: widget,
                                             clock: widget.scoreboard.generic.clock)
            }
            Divider()
            VStack(spacing: 13) {
                ScoreboardUndoButtonView(model: model, widget: widget)
                ScoreboardResetScoreButtonView(model: model, widget: widget)
            }
            VStack(spacing: 13) {
                ScoreboardIncrementHomeButtonView(model: model, widget: widget)
                ScoreboardIncrementAwayButtonView(model: model, widget: widget)
            }
        }
    }
}

struct WidgetScoreboardGenericGeneralSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        TextEditNavigationView(title: String(localized: "Title"), value: generic.title) { title in
            generic.title = title
        }
        .onChange(of: generic.title) { _ in
            model.resetSelectedScene(changeScene: false, attachCamera: false)
        }
        ScoreboardColorsView(model: model, widget: widget, scoreboard: scoreboard)
    }
}

struct WidgetScoreboardGenericSettingsView: View {
    let model: Model
    @ObservedObject var generic: SettingsWidgetGenericScoreboard
    @ObservedObject var clock: SettingsWidgetScoreboardClock

    private func isValidClockMaximum(value: String) -> String? {
        guard let maximum = Int(value) else {
            return String(localized: "Not a number")
        }
        guard maximum > 0 else {
            return String(localized: "Too small")
        }
        guard maximum <= 180 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitClockMaximum(value: String) {
        guard let maximum = Int(value) else {
            return
        }
        clock.maximum = maximum
    }

    private func formatMaximum(value: String) -> String {
        guard let maximum = Int(value) else {
            return ""
        }
        return formatFullDuration(seconds: 60 * maximum)
    }

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Home"), value: generic.home) { home in
                generic.home = home
            }
            .onChange(of: generic.home) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            TextEditNavigationView(title: String(localized: "Away"), value: generic.away) { away in
                generic.away = away
            }
            .onChange(of: generic.away) { _ in
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        } header: {
            Text("Teams")
        }
        Section {
            TextEditNavigationView(title: String(localized: "Maximum"),
                                   value: String(clock.maximum),
                                   onChange: isValidClockMaximum,
                                   onSubmit: submitClockMaximum,
                                   valueFormat: formatMaximum)
                .onChange(of: clock.maximum) { _ in
                    clock.reset()
                    model.resetSelectedScene(changeScene: false, attachCamera: false)
                }
            Picker("Direction", selection: $clock.direction) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: clock.direction) { _ in
                clock.reset()
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        } header: {
            Text("Clock")
        }
    }
}
