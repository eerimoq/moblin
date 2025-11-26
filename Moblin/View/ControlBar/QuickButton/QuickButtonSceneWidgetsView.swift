import AVFoundation
import SwiftUI

struct TimerWidgetView: View {
    let name: String
    @ObservedObject var timer: SettingsWidgetTextTimer
    let index: Int
    let textEffect: TextEffect
    let indented: Bool

    private func updateTextEffect() {
        textEffect.setEndTime(index: index, endTime: timer.textEffectEndTime())
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
    private let textEffect: TextEffect
    private var indented: Bool

    init(name: String, stopwatch: SettingsWidgetTextStopwatch, index: Int, textEffect: TextEffect, indented: Bool) {
        self.name = name
        self.stopwatch = stopwatch
        self.index = index
        self.textEffect = textEffect
        self.indented = indented
    }

    private func updateTextEffect() {
        textEffect.setStopwatch(index: index, stopwatch: stopwatch.clone())
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
                stopwatch.totalElapsed = 0.0
                stopwatch.running = false
                updateTextEffect()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title)
            }
            .padding([.trailing], 10)
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
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct CheckboxWidgetView: View {
    private let name: String
    private let checkbox: SettingsWidgetTextCheckbox
    private let index: Int
    private let textEffect: TextEffect
    private var indented: Bool
    @State var image: String

    init(
        name: String,
        checkbox: SettingsWidgetTextCheckbox,
        index: Int,
        textEffect: TextEffect,
        indented: Bool
    ) {
        self.name = name
        self.checkbox = checkbox
        self.index = index
        self.textEffect = textEffect
        self.indented = indented
        image = checkbox.checked ? "checkmark.square" : "square"
    }

    private func updateTextEffect() {
        textEffect.setCheckbox(index: index, checked: checkbox.checked)
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
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct RatingWidgetView: View {
    private let name: String
    private let rating: SettingsWidgetTextRating
    private let index: Int
    private let textEffect: TextEffect
    private var indented: Bool
    @State private var ratingSelection: Int

    init(
        name: String,
        rating: SettingsWidgetTextRating,
        index: Int,
        textEffect: TextEffect,
        indented: Bool
    ) {
        self.name = name
        self.rating = rating
        self.index = index
        self.textEffect = textEffect
        self.indented = indented
        ratingSelection = rating.rating
    }

    private func updateTextEffect() {
        textEffect.setRating(index: index, rating: rating.rating)
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
    private let textEffect: TextEffect
    private var indented: Bool

    init(
        name: String,
        lapTimes: SettingsWidgetTextLapTimes,
        index: Int,
        textEffect: TextEffect,
        indented: Bool
    ) {
        self.name = name
        self.lapTimes = lapTimes
        self.index = index
        self.textEffect = textEffect
        self.indented = indented
    }

    private func updateTextEffect() {
        textEffect.setLapTimes(index: index, lapTimes: lapTimes.lapTimes)
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
        .buttonStyle(BorderlessButtonStyle())
    }
}

private struct WidgetTextView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var text: SettingsWidgetText

    var body: some View {
        if let textEffect = model.getTextEffect(id: widget.id) {
            let textFormat = loadTextFormat(format: text.formatString)
            ForEach(text.timers) { timer in
                let index = text.timers.firstIndex(where: { $0 === timer }) ?? 0
                TimerWidgetView(
                    name: String(localized: "Timer \(index + 1)"),
                    timer: timer,
                    index: index,
                    textEffect: textEffect,
                    indented: true
                )
            }
            ForEach(text.stopwatches) { stopwatch in
                let index = text.stopwatches.firstIndex(where: { $0 === stopwatch }) ?? 0
                StopwatchWidgetView(
                    name: String(localized: "Stopwatch \(index + 1)"),
                    stopwatch: stopwatch,
                    index: index,
                    textEffect: textEffect,
                    indented: true
                )
            }
            ForEach(text.checkboxes) { checkbox in
                let index = text.checkboxes.firstIndex(where: { $0 === checkbox }) ?? 0
                CheckboxWidgetView(
                    name: textFormat.getCheckboxText(index: index),
                    checkbox: checkbox,
                    index: index,
                    textEffect: textEffect,
                    indented: true
                )
            }
            ForEach(text.ratings) { rating in
                let index = text.ratings.firstIndex(where: { $0 === rating }) ?? 0
                RatingWidgetView(
                    name: String(localized: "Rating \(index + 1)"),
                    rating: rating,
                    index: index,
                    textEffect: textEffect,
                    indented: true
                )
            }
            ForEach(text.lapTimes) { lapTimes in
                let index = text.lapTimes.firstIndex(where: { $0 === lapTimes }) ?? 0
                LapTimesWidgetView(
                    name: String(localized: "Lap times \(index + 1)"),
                    lapTimes: lapTimes,
                    index: index,
                    textEffect: textEffect,
                    indented: true
                )
            }
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
        if widget.type == .text {
            WidgetTextView(model: model, widget: widget, text: widget.text)
        }
    }
}

struct QuickButtonSceneWidgetsView: View {
    let model: Model
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
        }
        .navigationTitle("Scene widgets")
    }
}
