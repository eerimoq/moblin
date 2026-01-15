import AVFoundation
import SwiftUI

private struct TimeComponentPickerView: View {
    let title: LocalizedStringKey
    let range: Range<Int>
    @Binding var time: Int

    var body: some View {
        VStack {
            Text(title)
            Picker("", selection: $time) {
                ForEach(range, id: \.self) {
                    Text(String($0))
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 150)
        }
    }
}

private struct TimeButtonView: View {
    let text: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(text)
                .frame(width: 100, height: 30)
        }
    }
}

private struct TimePickerView: View {
    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    private let onSet: (Double) -> Void
    private let onCancel: () -> Void

    init(time: Double, onSet: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        let time = Int(time)
        seconds = time % 60
        minutes = (time / 60) % 60
        hours = min(time / 3600, 23)
        self.onSet = onSet
        self.onCancel = onCancel
    }

    var body: some View {
        VStack {
            HStack {
                TimeComponentPickerView(title: "Hours", range: 0 ..< 24, time: $hours)
                TimeComponentPickerView(title: "Minutes", range: 0 ..< 60, time: $minutes)
                TimeComponentPickerView(title: "Seconds", range: 0 ..< 60, time: $seconds)
            }
            .padding()
            HStack {
                TimeButtonView(text: "Set") {
                    onSet(Double(hours * 3600 + minutes * 60 + seconds))
                }
                TimeButtonView(text: "Cancel") {
                    onCancel()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }
}

struct TimerWidgetView: View {
    let name: String
    @ObservedObject var timer: SettingsWidgetTextTimer
    let index: Int
    let textEffects: [TextEffect]
    let indented: Bool
    @State private var presentingSetTime: Bool = false

    private func updateTextEffect() {
        for effect in textEffects {
            effect.setEndTime(index: index, endTime: timer.textEffectEndTime())
        }
    }

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(name)
                    Spacer()
                    Text(timer.format())
                }
                HStack {
                    Picker("", selection: $timer.delta) {
                        ForEach([1, 2, 5, 15, 60], id: \.self) { delta in
                            Text("\(delta) min")
                                .tag(delta)
                        }
                    }
                    Button {
                        timer.add(delta: -60 * Double(timer.delta))
                        updateTextEffect()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title)
                    }
                    Button {
                        timer.add(delta: 60 * Double(timer.delta))
                        updateTextEffect()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title)
                    }
                    Button {
                        presentingSetTime = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                    }
                    .popover(isPresented: $presentingSetTime, arrowEdge: .bottom) {
                        TimePickerView(time: timer.timeLeft(),
                                       onSet: {
                                           timer.set(time: $0)
                                           updateTextEffect()
                                           presentingSetTime = false
                                       },
                                       onCancel: {
                                           presentingSetTime = false
                                       })
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct StopwatchWidgetView: View {
    private let name: String
    @ObservedObject var stopwatch: SettingsWidgetTextStopwatch
    private let index: Int
    private let textEffects: [TextEffect]
    private var indented: Bool
    @State private var presentingSetTime: Bool = false

    init(
        name: String,
        stopwatch: SettingsWidgetTextStopwatch,
        index: Int,
        textEffects: [TextEffect],
        indented: Bool
    ) {
        self.name = name
        self.stopwatch = stopwatch
        self.index = index
        self.textEffects = textEffects
        self.indented = indented
    }

    private func updateTextEffect() {
        for effect in textEffects {
            effect.setStopwatch(index: index, stopwatch: stopwatch.clone())
        }
    }

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(name)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button {
                        presentingSetTime = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                    }
                    .popover(isPresented: $presentingSetTime, arrowEdge: .bottom) {
                        TimePickerView(time: stopwatch.currentTime(),
                                       onSet: {
                                           stopwatch.playPressedTime = .now
                                           stopwatch.totalElapsed = $0
                                           updateTextEffect()
                                           presentingSetTime = false
                                       },
                                       onCancel: {
                                           presentingSetTime = false
                                       })
                    }
                    Button {
                        stopwatch.totalElapsed = 0.0
                        stopwatch.running = false
                        updateTextEffect()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                    }
                    Button {
                        stopwatch.running.toggle()
                        if stopwatch.running {
                            stopwatch.playPressedTime = .now
                        } else {
                            stopwatch.totalElapsed += stopwatch.playPressedTime.duration(to: .now).seconds
                        }
                        updateTextEffect()
                    } label: {
                        Image(systemName: stopwatch.running ? "stop" : "play")
                            .font(.title)
                            .frame(width: 35)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct CheckboxWidgetView: View {
    private let name: String
    private let checkbox: SettingsWidgetTextCheckbox
    private let index: Int
    private let textEffects: [TextEffect]
    private var indented: Bool
    @State var image: String

    init(
        name: String,
        checkbox: SettingsWidgetTextCheckbox,
        index: Int,
        textEffects: [TextEffect],
        indented: Bool
    ) {
        self.name = name
        self.checkbox = checkbox
        self.index = index
        self.textEffects = textEffects
        self.indented = indented
        image = checkbox.checked ? "checkmark.square" : "square"
    }

    private func updateTextEffect() {
        for effect in textEffects {
            effect.setCheckbox(index: index, checked: checkbox.checked)
        }
    }

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            Text(name)
            Spacer()
            Button {
                checkbox.checked = !checkbox.checked
                image = checkbox.checked ? "checkmark.square" : "square"
                updateTextEffect()
            } label: {
                Image(systemName: image)
                    .font(.title)
            }
        }
        .buttonStyle(.borderless)
    }
}

struct RatingWidgetView: View {
    private let name: String
    private let rating: SettingsWidgetTextRating
    private let index: Int
    private let textEffects: [TextEffect]
    private var indented: Bool
    @State private var ratingSelection: Int

    init(
        name: String,
        rating: SettingsWidgetTextRating,
        index: Int,
        textEffects: [TextEffect],
        indented: Bool
    ) {
        self.name = name
        self.rating = rating
        self.index = index
        self.textEffects = textEffects
        self.indented = indented
        ratingSelection = rating.rating
    }

    private func updateTextEffect() {
        for effect in textEffects {
            effect.setRating(index: index, rating: rating.rating)
        }
    }

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            Picker(selection: $ratingSelection) {
                ForEach(0 ..< 6) { rating in
                    Text(String(rating))
                }
            } label: {
                Text(name)
            }
            .onChange(of: ratingSelection) {
                rating.rating = $0
                updateTextEffect()
            }
        }
    }
}

struct LapTimesWidgetView: View {
    private let name: String
    private let lapTimes: SettingsWidgetTextLapTimes
    private let index: Int
    private let textEffects: [TextEffect]
    private var indented: Bool

    init(
        name: String,
        lapTimes: SettingsWidgetTextLapTimes,
        index: Int,
        textEffects: [TextEffect],
        indented: Bool
    ) {
        self.name = name
        self.lapTimes = lapTimes
        self.index = index
        self.textEffects = textEffects
        self.indented = indented
    }

    private func updateTextEffect() {
        for effect in textEffects {
            effect.setLapTimes(index: index, lapTimes: lapTimes.lapTimes)
        }
    }

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            Text(name)
            Spacer()
            Button {
                lapTimes.currentLapStartTime = nil
                lapTimes.lapTimes = []
                updateTextEffect()
            } label: {
                Image(systemName: "trash")
                    .font(.title)
            }
            .padding([.trailing], 10)
            Button {
                let now = Date().timeIntervalSince1970
                let lastIndex = lapTimes.lapTimes.endIndex - 1
                if lastIndex >= 0, let currentLapStartTime = lapTimes.currentLapStartTime {
                    lapTimes.lapTimes[lastIndex] = now - currentLapStartTime
                }
                lapTimes.currentLapStartTime = now
                lapTimes.lapTimes.append(0)
                updateTextEffect()
            } label: {
                Image(systemName: "stopwatch")
                    .font(.title)
            }
            .padding([.trailing], 10)
            Button {
                if let currentLapStartTime = lapTimes.currentLapStartTime {
                    let lastIndex = lapTimes.lapTimes.endIndex - 1
                    if lastIndex >= 0 {
                        let now = Date().timeIntervalSince1970
                        lapTimes.lapTimes[lastIndex] = now - currentLapStartTime
                    }
                    lapTimes.currentLapStartTime = nil
                    lapTimes.lapTimes.append(.infinity)
                }
                updateTextEffect()
            } label: {
                Image(systemName: "flag.checkered")
                    .font(.title)
            }
        }
        .buttonStyle(.borderless)
    }
}

struct WheelOfLuckWidgetView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    let effect: WheelOfLuckEffect
    let indented: Bool

    var body: some View {
        HStack {
            if indented {
                Text("")
                Text("").frame(width: iconWidth)
            }
            Spacer()
            Button {
                widget.wheelOfLuck.shuffle()
                model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: widget.wheelOfLuck)

            } label: {
                Image(systemName: "shuffle")
                    .font(.title)
            }
            .padding([.trailing], 10)
            Button {
                effect.spin()
            } label: {
                Image(systemName: "play")
                    .font(.title)
            }
        }
        .buttonStyle(.borderless)
    }
}

private struct WidgetTextView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var text: SettingsWidgetText

    var body: some View {
        let textEffects = model.getTextEffects(id: widget.id)
        if !textEffects.isEmpty {
            let textFormat = loadTextFormat(format: text.formatString)
            ForEach(text.timers) { timer in
                let index = text.timers.firstIndex(where: { $0 === timer }) ?? 0
                TimerWidgetView(
                    name: String(localized: "Timer \(index + 1)"),
                    timer: timer,
                    index: index,
                    textEffects: textEffects,
                    indented: true
                )
            }
            ForEach(text.stopwatches) { stopwatch in
                let index = text.stopwatches.firstIndex(where: { $0 === stopwatch }) ?? 0
                StopwatchWidgetView(
                    name: String(localized: "Stopwatch \(index + 1)"),
                    stopwatch: stopwatch,
                    index: index,
                    textEffects: textEffects,
                    indented: true
                )
            }
            ForEach(text.checkboxes) { checkbox in
                let index = text.checkboxes.firstIndex(where: { $0 === checkbox }) ?? 0
                CheckboxWidgetView(
                    name: textFormat.getCheckboxText(index: index),
                    checkbox: checkbox,
                    index: index,
                    textEffects: textEffects,
                    indented: true
                )
            }
            ForEach(text.ratings) { rating in
                let index = text.ratings.firstIndex(where: { $0 === rating }) ?? 0
                RatingWidgetView(
                    name: String(localized: "Rating \(index + 1)"),
                    rating: rating,
                    index: index,
                    textEffects: textEffects,
                    indented: true
                )
            }
            ForEach(text.lapTimes) { lapTimes in
                let index = text.lapTimes.firstIndex(where: { $0 === lapTimes }) ?? 0
                LapTimesWidgetView(
                    name: String(localized: "Lap times \(index + 1)"),
                    lapTimes: lapTimes,
                    index: index,
                    textEffects: textEffects,
                    indented: true
                )
            }
        }
    }
}

private struct WidgetWheelOfLuckView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        if let effect = model.getWheelOfLuckEffect(id: widget.id) {
            WheelOfLuckWidgetView(model: model, widget: widget, effect: effect, indented: true)
        }
    }
}

private struct WidgetView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var sceneWidget: SettingsSceneWidget

    var body: some View {
        NavigationLink {
            SceneWidgetSettingsView(
                model: model,
                database: database,
                sceneWidget: sceneWidget,
                widget: widget
            )
        } label: {
            Toggle(isOn: $widget.enabled) {
                IconAndTextView(
                    image: widget.image(),
                    text: widget.name,
                    longDivider: true
                )
            }
            .onChange(of: widget.enabled) { _ in
                model.reloadSpeechToText()
                model.sceneUpdated(attachCamera: model.isCaptureDeviceWidget(widget: widget))
            }
        }
        switch widget.type {
        case .text:
            WidgetTextView(model: model, widget: widget, text: widget.text)
        case .wheelOfLuck:
            WidgetWheelOfLuckView(model: model, widget: widget)
        default:
            EmptyView()
        }
    }
}

struct QuickButtonSceneWidgetsView: View {
    @EnvironmentObject var model: Model
    // periphery:ignore
    @ObservedObject var sceneSelector: SceneSelector

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.widgetsInCurrentScene(onlyEnabled: false)) { widget in
                        WidgetView(model: model,
                                   database: model.database,
                                   widget: widget.widget,
                                   sceneWidget: widget.sceneWidget)
                    }
                }
            }
            ShortcutSectionView {
                ScenesShortcutView(database: model.database)
            }
        }
        .navigationTitle("Scene widgets")
    }
}
