import AVFoundation
import SwiftUI

struct TimerWidgetView: View {
    private let name: String
    private let timer: SettingsWidgetTextTimer
    private let index: Int
    private let textEffect: TextEffect
    private var indented: Bool
    @State private var delta: Int
    @State private var endTime: Double

    init(name: String, timer: SettingsWidgetTextTimer, index: Int, textEffect: TextEffect, indented: Bool) {
        self.name = name
        self.timer = timer
        self.index = index
        self.textEffect = textEffect
        self.indented = indented
        delta = timer.delta
        endTime = timer.endTime
    }

    private func formatTimer() -> String {
        return Duration(secondsComponent: Int64(max(timeLeft(), 0)), attosecondsComponent: 0)
            .formatWithSeconds()
    }

    private func updateTextEffect() {
        textEffect.setEndTime(index: index, endTime: .now.advanced(by: .seconds(max(timeLeft(), 0))))
    }

    private func timeLeft() -> Double {
        return utcTimeDeltaFromNow(to: endTime)
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
                    Text(formatTimer())
                }
                HStack {
                    Picker("", selection: $delta) {
                        ForEach([1, 2, 5, 15, 60], id: \.self) { delta in
                            Text("\(delta) min")
                                .tag(delta)
                        }
                    }
                    .onChange(of: delta) { value in
                        timer.delta = value
                    }
                    Button {
                        endTime -= 60 * Double(delta)
                        timer.endTime = endTime
                        updateTextEffect()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title)
                    }
                    Button {
                        if timeLeft() < 0 {
                            endTime = Date().timeIntervalSince1970
                        }
                        endTime += 60 * Double(delta)
                        timer.endTime = endTime
                        updateTextEffect()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
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
            Button(action: {
                checkbox.checked = !checkbox.checked
                image = checkbox.checked ? "checkmark.square" : "square"
                updateTextEffect()
            }, label: {
                Image(systemName: image)
                    .font(.title)
            })
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
            .onChange(of: ratingSelection) { value in
                rating.rating = value
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
            Button(action: {
                lapTimes.currentLapStartTime = nil
                lapTimes.lapTimes = []
                updateTextEffect()
            }, label: {
                Image(systemName: "trash")
                    .font(.title)
            })
            .padding([.trailing], 10)
            Button(action: {
                let now = Date().timeIntervalSince1970
                let lastIndex = lapTimes.lapTimes.endIndex - 1
                if lastIndex >= 0, let currentLapStartTime = lapTimes.currentLapStartTime {
                    lapTimes.lapTimes[lastIndex] = now - currentLapStartTime
                }
                lapTimes.currentLapStartTime = now
                lapTimes.lapTimes.append(0)
                updateTextEffect()
            }, label: {
                Image(systemName: "stopwatch")
                    .font(.title)
            })
            .padding([.trailing], 10)
            Button(action: {
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
            }, label: {
                Image(systemName: "flag.checkered")
                    .font(.title)
            })
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct QuickButtonWidgetsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.widgetsInCurrentScene) { widget in
                        Toggle(isOn: Binding(get: {
                            widget.enabled!
                        }, set: { value in
                            widget.enabled = value
                            model.reloadSpeechToText()
                            model.sceneUpdated(attachCamera: model.isCaptureDeviceVideoSoureWidget(widget: widget))
                        })) {
                            IconAndTextView(
                                image: widgetImage(widget: widget),
                                text: widget.name,
                                longDivider: true
                            )
                        }
                        if widget.type == .text {
                            if let textEffect = model.getTextEffect(id: widget.id) {
                                let textFormat = loadTextFormat(format: widget.text.formatString)
                                ForEach(widget.text.timers!) { timer in
                                    let index = widget.text.timers!.firstIndex(where: { $0 === timer }) ?? 0
                                    TimerWidgetView(
                                        name: "Timer \(index + 1)",
                                        timer: timer,
                                        index: index,
                                        textEffect: textEffect,
                                        indented: true
                                    )
                                }
                                ForEach(widget.text.checkboxes!) { checkbox in
                                    let index = widget.text.checkboxes!
                                        .firstIndex(where: { $0 === checkbox }) ?? 0
                                    CheckboxWidgetView(
                                        name: textFormat.getCheckboxText(index: index),
                                        checkbox: checkbox,
                                        index: index,
                                        textEffect: textEffect,
                                        indented: true
                                    )
                                }
                                ForEach(widget.text.ratings!) { rating in
                                    let index = widget.text.ratings!
                                        .firstIndex(where: { $0 === rating }) ?? 0
                                    RatingWidgetView(
                                        name: "Rating \(index + 1)",
                                        rating: rating,
                                        index: index,
                                        textEffect: textEffect,
                                        indented: true
                                    )
                                }
                                ForEach(widget.text.lapTimes!) { lapTimes in
                                    let index = widget.text.lapTimes!
                                        .firstIndex(where: { $0 === lapTimes }) ?? 0
                                    LapTimesWidgetView(
                                        name: "Lap times \(index + 1)",
                                        lapTimes: lapTimes,
                                        index: index,
                                        textEffect: textEffect,
                                        indented: true
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Widgets")
    }
}
