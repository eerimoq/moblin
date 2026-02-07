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

struct ScoreboardUndoButtonView: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

struct ScoreboardIncrementButtonView: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title)
        }
        .buttonStyle(.borderless)
    }
}

struct ScoreboardResetScoreButtonView: View {
    let action: () -> Void
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
                action()
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
                ScoreboardUndoButtonView {
                    model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .undo))
                }
                ScoreboardResetScoreButtonView {
                    model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .reset))
                }
            }
            VStack(spacing: 13) {
                ScoreboardIncrementButtonView {
                    model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .incrementHome))
                }
                ScoreboardIncrementButtonView {
                    model.handleUpdateGenericScoreboard(action: .init(id: widget.id, action: .incrementAway))
                }
            }
        }
    }
}

struct WidgetScoreboardGenericGeneralSettingsView: View {
    @ObservedObject var widget: SettingsWidget
    let scoreboard: SettingsWidgetScoreboard
    @ObservedObject var generic: SettingsWidgetGenericScoreboard
    let updated: () -> Void

    var body: some View {
        TextEditNavigationView(title: String(localized: "Title"), value: generic.title) { title in
            generic.title = title
        }
        .onChange(of: generic.title) { _ in
            updated()
        }
        ScoreboardColorsView(scoreboard: scoreboard, updated: updated)
    }
}

struct WidgetScoreboardGenericSettingsView: View {
    @ObservedObject var generic: SettingsWidgetGenericScoreboard
    @ObservedObject var clock: SettingsWidgetScoreboardClock
    let updated: () -> Void

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
                updated()
            }
            TextEditNavigationView(title: String(localized: "Away"), value: generic.away) { away in
                generic.away = away
            }
            .onChange(of: generic.away) { _ in
                updated()
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
                    updated()
                }
            Picker("Direction", selection: $clock.direction) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) { direction in
                    Text(direction.toString())
                }
            }
            .onChange(of: clock.direction) { _ in
                clock.reset()
                updated()
            }
        } header: {
            Text("Clock")
        }
    }
}
