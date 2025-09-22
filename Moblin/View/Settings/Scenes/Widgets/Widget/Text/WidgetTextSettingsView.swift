import PhotosUI
import SwiftUI

private struct Suggestion: Identifiable {
    let id: Int
    let name: String
    let text: String
}

private let suggestionCountry = "{countryFlag} {country}"
private let suggestionCity = "{countryFlag} {city}"
private let suggestionMovement = "📏 {distance} 💨 {speed} 🏔️ {altitude}"
private let suggestionHeartRate = "♥️ {heartRate}"
private let suggestionSubtitles = "{subtitles}"
private let suggestionMuted = "{muted}"
private let suggestionTime = "🕑 {shortTime}"
private let suggestionDate = "📅 {date}"
private let suggestionFullDate = "📅 {fullDate}"
private let suggestionTimer = "⏳ {timer}"
private let suggestionStopwatch = "⏱️ {stopwatch}"
private let suggestionWeather = "{conditions} {temperature}"
private let suggestionTravel =
    "\(suggestionWeather)\n\(suggestionTime)\n\(suggestionCity)\n\(suggestionMovement)"
private let suggestionDebug = "{time}\n{bitrateAndTotal}\n{debugOverlay}"
private let suggestionWorkoutTest = "{activeEnergyBurned} {power} {stepCount} {workoutDistance}"
private let suggestionTesla = "🚗 Tesla\n⚙️ {teslaDrive}\n🔋 {teslaBatteryLevel}\n🔈 {teslaMedia}"
private let suggestionRacing = "🏎️ Racing 🏎️\n{lapTimes}"

private let suggestions = createSuggestions()

private func createSuggestions() -> [Suggestion] {
    var suggestions = [
        Suggestion(id: 0, name: String(localized: "Travel"), text: suggestionTravel),
        Suggestion(id: 1, name: String(localized: "Weather"), text: suggestionWeather),
        Suggestion(id: 2, name: String(localized: "Time"), text: suggestionTime),
        Suggestion(id: 3, name: String(localized: "Date"), text: suggestionDate),
        Suggestion(id: 4, name: String(localized: "Full date"), text: suggestionFullDate),
        Suggestion(id: 5, name: String(localized: "Timer"), text: suggestionTimer),
        Suggestion(id: 6, name: String(localized: "Stopwatch"), text: suggestionStopwatch),
        Suggestion(id: 7, name: String(localized: "City"), text: suggestionCity),
        Suggestion(id: 8, name: String(localized: "Country"), text: suggestionCountry),
        Suggestion(id: 9, name: String(localized: "Movement"), text: suggestionMovement),
    ]
    if isPhone() {
        suggestions += [
            Suggestion(id: 10, name: String(localized: "Heart rate"), text: suggestionHeartRate),
        ]
    }
    suggestions += [
        Suggestion(id: 11, name: String(localized: "Subtitles"), text: suggestionSubtitles),
        Suggestion(id: 12, name: String(localized: "Muted"), text: suggestionMuted),
        Suggestion(id: 13, name: String(localized: "Debug"), text: suggestionDebug),
        Suggestion(id: 14, name: String(localized: "Workout test"), text: suggestionWorkoutTest),
        Suggestion(id: 15, name: String(localized: "Tesla"), text: suggestionTesla),
        Suggestion(id: 16, name: String(localized: "Racing"), text: suggestionRacing),
    ]
    return suggestions
}

private struct SuggestionView: View {
    let suggestion: Suggestion
    @Binding var text: String
    let dismiss: () -> Void
    @State var isPresentingConfirmation = false

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                isPresentingConfirmation = true
            } label: {
                Text(suggestion.name)
                    .font(.title3)
            }
            .confirmationDialog("", isPresented: $isPresentingConfirmation) {
                Button("Yes", role: .destructive) {
                    text = suggestion.text
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to replace the content of the current text widget?")
            }
            Text(suggestion.text)
        }
    }
}

private struct SuggestionsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var text: String

    var body: some View {
        Form {
            Section {
                ForEach(suggestions) { suggestion in
                    SuggestionView(suggestion: suggestion, text: $text) {
                        dismiss()
                    }
                    .tag(suggestion.id)
                }
            }
        }
        .navigationTitle("Suggestions")
    }
}

private struct FormatView: View {
    @EnvironmentObject var model: Model
    let title: String
    let description: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                text += title
                model.makeToast(title: "Appended \(title) to widget text")
            } label: {
                Text(title)
                    .font(.title3)
            }
            Text(description)
        }
    }
}

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    let widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0
    @FocusState var editingText: Bool

    private func updateTimers(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfTimers = parts.filter { $0 == .timer }.count
        for index in 0 ..< numberOfTimers where index >= widget.text.timers.count {
            widget.text.timers.append(.init())
        }
        while widget.text.timers.count > numberOfTimers {
            widget.text.timers.removeLast()
        }
        textEffect?.setTimersEndTime(endTimes: widget.text.timers.map {
            .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
        })
    }

    private func updateStopwatches(_: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfStopwatches = parts.filter { $0 == .stopwatch }.count
        for index in 0 ..< numberOfStopwatches where index >= widget.text.stopwatches.count {
            widget.text.stopwatches.append(.init())
        }
        while widget.text.stopwatches.count > numberOfStopwatches {
            widget.text.stopwatches.removeLast()
        }
        // textEffect?.setTimersEndTime(endTimes: widget.text.timers.map {
        //     .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
        // })
    }

    private func updateCheckboxes(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfCheckboxes = parts.filter { $0 == .checkbox }.count
        for index in 0 ..< numberOfCheckboxes where index >= widget.text.checkboxes.count {
            widget.text.checkboxes.append(.init())
        }
        while widget.text.checkboxes.count > numberOfCheckboxes {
            widget.text.checkboxes.removeLast()
        }
        textEffect?.setCheckboxes(checkboxes: widget.text.checkboxes.map { $0.checked })
    }

    private func updateRatings(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfRatings = parts.filter { $0 == .rating }.count
        for index in 0 ..< numberOfRatings where index >= widget.text.ratings.count {
            widget.text.ratings.append(.init())
        }
        while widget.text.ratings.count > numberOfRatings {
            widget.text.ratings.removeLast()
        }
        textEffect?.setRatings(ratings: widget.text.ratings.map { $0.rating })
    }

    private func updateLapTimes(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfLapTimes = parts.filter { $0 == .lapTimes }.count
        for index in 0 ..< numberOfLapTimes where index >= widget.text.lapTimes.count {
            widget.text.lapTimes.append(.init())
        }
        while widget.text.lapTimes.count > numberOfLapTimes {
            widget.text.lapTimes.removeLast()
        }
        textEffect?.setLapTimes(lapTimes: widget.text.lapTimes.map { $0.lapTimes })
    }

    private func updateSubtitles(_: TextEffect?, _ parts: [TextFormatPart]) {
        widget.text.subtitles.removeAll()
        for part in parts {
            switch part {
            case let .subtitles(identifier):
                let item = SettingsWidgetTextSubtitles()
                item.identifier = identifier
                widget.text.subtitles.append(item)
            default:
                break
            }
        }
        widget.text.needsSubtitles = !widget.text.subtitles.isEmpty
        model.reloadSpeechToText()
    }

    private func updateNeedsWeather(_ parts: [TextFormatPart]) {
        widget.text.needsWeather = !parts.filter {
            switch $0 {
            case .conditions:
                return true
            case .temperature:
                return true
            default:
                return false
            }
        }.isEmpty
        model.startWeatherManager()
    }

    private func updateNeedsGeography(_ parts: [TextFormatPart]) {
        widget.text.needsGeography = !parts.filter {
            switch $0 {
            case .country:
                return true
            case .countryFlag:
                return true
            case .state:
                return true
            case .city:
                return true
            default:
                return false
            }
        }.isEmpty
        model.startGeographyManager()
    }

    private func updateNeedsGForce(_ parts: [TextFormatPart]) {
        widget.text.needsGForce = !parts.filter {
            switch $0 {
            case .gForce:
                return true
            case .gForceRecentMax:
                return true
            case .gForceMax:
                return true
            default:
                return false
            }
        }.isEmpty
        model.startGForceManager()
    }

    private func update() {
        widget.text.formatString = value
        let textEffect = model.getTextEffect(id: widget.id)
        textEffect?.setFormat(format: value)
        let parts = loadTextFormat(format: value)
        updateTimers(textEffect, parts)
        updateStopwatches(textEffect, parts)
        updateCheckboxes(textEffect, parts)
        updateRatings(textEffect, parts)
        updateLapTimes(textEffect, parts)
        updateSubtitles(textEffect, parts)
        updateNeedsWeather(parts)
        updateNeedsGeography(parts)
        updateNeedsGForce(parts)
        model.sceneUpdated()
    }

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $value)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($editingText)
            } footer: {
                if isPhone() {
                    HStack {
                        Spacer()
                        Button("Done") {
                            editingText = false
                        }
                    }
                    .disabled(!editingText)
                }
            }
            Section {
                NavigationLink {
                    SuggestionsView(text: $value)
                } label: {
                    Text("Suggestions")
                }
            }
            Section {
                Text("Tap on items below to append them to the widget text.")
            }
            Section {
                FormatView(title: "{time}", description: String(localized: "Show time as HH:MM:SS"), text: $value)
                FormatView(title: "{shortTime}", description: String(localized: "Show time as HH:MM"), text: $value)
                FormatView(title: "{date}", description: String(localized: "Show date"), text: $value)
                FormatView(title: "{fullDate}", description: String(localized: "Show full date"), text: $value)
                FormatView(title: "{timer}", description: String(localized: "Show a timer"), text: $value)
                FormatView(title: "{stopwatch}", description: String(localized: "Show a stopwatch"), text: $value)
                FormatView(title: "{checkbox}", description: String(localized: "Show a checkbox"), text: $value)
                FormatView(title: "{rating}", description: String(localized: "Show a 0-5 rating"), text: $value)
                FormatView(
                    title: "{subtitles}",
                    description: String(localized: "Show subtitles in app language"),
                    text: $value
                )
                FormatView(title: "{subtitles:<language-identifier>}",
                           description: String(localized: """
                           Show subtitles in given language. Download languages in \
                           iOS Settings → Apps → Translate → Languages. <language-identifier> is \
                           en for English, de for German, zh-Hans for Chinese, ...
                           """),
                           text: $value)
                FormatView(title: "{lapTimes}", description: String(localized: "Show lap times"), text: $value)
                FormatView(title: "{muted}", description: String(localized: "Show muted"), text: $value)
                FormatView(title: "{browserTitle}", description: String(localized: "Show browser title"), text: $value)
            } header: {
                Text("General")
            }
            Section {
                FormatView(title: "{country}", description: String(localized: "Show country"), text: $value)
                FormatView(title: "{countryFlag}", description: String(localized: "Show country flag"), text: $value)
                FormatView(title: "{state}", description: String(localized: "Show state"), text: $value)
                FormatView(title: "{city}", description: String(localized: "Show city"), text: $value)
                FormatView(title: "{speed}", description: String(localized: "Show speed"), text: $value)
                FormatView(title: "{averageSpeed}", description: String(localized: "Show average speed"), text: $value)
                FormatView(title: "{altitude}", description: String(localized: "Show altitude"), text: $value)
                FormatView(title: "{distance}", description: String(localized: "Show distance"), text: $value)
                FormatView(title: "{slope}", description: String(localized: "Show slope"), text: $value)
                FormatView(title: "{gForce}", description: String(localized: "Show G-force"), text: $value)
                FormatView(
                    title: "{gForceRecentMax}",
                    description: String(localized: "Show recent max G-force"),
                    text: $value
                )
                FormatView(title: "{gForceMax}", description: String(localized: "Show max G-force"), text: $value)
            } header: {
                Text("Location (if Settings -> Location is enabled)")
            }
            Section {
                FormatView(title: "{conditions}", description: String(localized: "Show conditions"), text: $value)
                FormatView(title: "{temperature}", description: String(localized: "Show temperature"), text: $value)
            } header: {
                Text("Weather (if Settings -> Location is enabled)")
            }
            Section {
                if isPhone() {
                    FormatView(
                        title: "{heartRate}",
                        description: String(localized: "Show Apple Watch heart rate"),
                        text: $value
                    )
                }
                ForEach(model.database.heartRateDevices.devices) { device in
                    FormatView(
                        title: "{heartRate:\(device.name)}",
                        description: String(
                            localized: "Show heart rate for heart rate device called \"\(device.name)\""
                        ),
                        text: $value
                    )
                }
            } header: {
                Text("Workout")
            }
            Section {
                FormatView(
                    title: "{teslaBatteryLevel}",
                    description: String(localized: "Show Tesla battery level"),
                    text: $value
                )
                FormatView(
                    title: "{teslaDrive}",
                    description: String(localized: "Show Tesla drive information"),
                    text: $value
                )
                FormatView(
                    title: "{teslaMedia}",
                    description: String(localized: "Show Tesla media information"),
                    text: $value
                )
            } header: {
                Text("Tesla (requires a Tesla)")
            }
            Section {
                FormatView(title: "{cyclingPower}", description: String(localized: "Show cycling power"), text: $value)
                FormatView(
                    title: "{cyclingCadence}",
                    description: String(localized: "Show cycling cadence"),
                    text: $value
                )
            } header: {
                Text("Cycling (requires a compatible bike)")
            }
            Section {
                FormatView(
                    title: "{bitrate}",
                    description: String(localized: "Show bitrate"),
                    text: $value
                )
                FormatView(
                    title: "{bitrateAndTotal}",
                    description: String(localized: "Show bitrate and total number of bytes sent"),
                    text: $value
                )
                FormatView(
                    title: "{debugOverlay}",
                    description: String(localized: "Show debug overlay (if enabled)"),
                    text: $value
                )
            } header: {
                Text("Debug")
            }
        }
        .onChange(of: value) { _ in
            update()
        }
        .navigationTitle("Text")
    }
}

struct WidgetTextSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var text: SettingsWidgetText

    var body: some View {
        Section {
            NavigationLink {
                TextSelectionView(widget: widget, value: text.formatString)
            } label: {
                TextItemView(name: String(localized: "Text"), value: widget.text.formatString)
            }
        }
        if !text.timers.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(text.timers) { timer in
                        let index = text.timers.firstIndex(where: { $0 === timer }) ?? 0
                        TimerWidgetView(
                            name: String(localized: "Timer \(index + 1)"),
                            timer: timer,
                            index: index,
                            textEffect: textEffect,
                            indented: false
                        )
                    }
                } header: {
                    Text("Timers")
                }
            }
        }
        if !text.stopwatches.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(text.stopwatches) { stopwatch in
                        let index = widget.text.stopwatches.firstIndex(where: { $0 === stopwatch }) ?? 0
                        StopwatchWidgetView(
                            name: String(localized: "Stopwatch \(index + 1)"),
                            stopwatch: stopwatch,
                            index: index,
                            textEffect: textEffect,
                            indented: false
                        )
                    }
                } header: {
                    Text("Stopwatches")
                }
            }
        }
        if !text.checkboxes.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                let textFormat = loadTextFormat(format: text.formatString)
                Section {
                    ForEach(text.checkboxes) { checkbox in
                        let index = text.checkboxes.firstIndex(where: { $0 === checkbox }) ?? 0
                        CheckboxWidgetView(
                            name: textFormat.getCheckboxText(index: index),
                            checkbox: checkbox,
                            index: index,
                            textEffect: textEffect,
                            indented: false
                        )
                    }
                } header: {
                    Text("Checkboxes")
                }
            }
        }
        if !text.ratings.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(text.ratings) { rating in
                        let index = text.ratings.firstIndex(where: { $0 === rating }) ?? 0
                        RatingWidgetView(
                            name: String(localized: "Rating \(index + 1)"),
                            rating: rating,
                            index: index,
                            textEffect: textEffect,
                            indented: false
                        )
                    }
                } header: {
                    Text("Ratings")
                }
            }
        }
        if !text.lapTimes.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(text.lapTimes) { lapTimes in
                        let index = text.lapTimes.firstIndex(where: { $0 === lapTimes }) ?? 0
                        LapTimesWidgetView(
                            name: String(localized: "Lap times \(index + 1)"),
                            lapTimes: lapTimes,
                            index: index,
                            textEffect: textEffect,
                            indented: false
                        )
                    }
                } header: {
                    Text("Lap times")
                }
            }
        }
        Section {
            ColorPicker("Background", selection: $text.backgroundColorColor, supportsOpacity: true)
                .onChange(of: text.backgroundColorColor) { _ in
                    guard let color = text.backgroundColorColor.toRgb() else {
                        return
                    }
                    text.backgroundColor = color
                    model.getTextEffect(id: widget.id)?.setBackgroundColor(color: color)
                    model.remoteSceneSettingsUpdated()
                }
            ColorPicker("Foreground", selection: $text.foregroundColorColor, supportsOpacity: true)
                .onChange(of: text.foregroundColorColor) { _ in
                    guard let color = text.foregroundColorColor.toRgb() else {
                        return
                    }
                    text.foregroundColor = color
                    model.getTextEffect(id: widget.id)?.setForegroundColor(color: color)
                    model.remoteSceneSettingsUpdated()
                }
        } header: {
            Text("Colors")
        }
        Section {
            HStack {
                Text("Size")
                Slider(
                    value: $text.fontSizeFloat,
                    in: 10 ... 200,
                    step: 5,
                    label: {
                        EmptyView()
                    }
                )
                .onChange(of: text.fontSizeFloat) { _ in
                    text.fontSize = Int(text.fontSizeFloat)
                    model.getTextEffect(id: widget.id)?.setFontSize(size: CGFloat(text.fontSizeFloat))
                    model.remoteSceneSettingsUpdated()
                }
                Text(String(Int(text.fontSizeFloat)))
                    .frame(width: 35)
            }
            HStack {
                Text("Design")
                Spacer()
                Picker("", selection: $text.fontDesign) {
                    ForEach(SettingsFontDesign.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: text.fontDesign) { _ in
                    model.getTextEffect(id: widget.id)?.setFontDesign(design: text.fontDesign.toSystem())
                    model.remoteSceneSettingsUpdated()
                }
            }
            HStack {
                Text("Weight")
                Spacer()
                Picker("", selection: $text.fontWeight) {
                    ForEach(SettingsFontWeight.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: text.fontWeight) { _ in
                    model.getTextEffect(id: widget.id)?.setFontWeight(weight: text.fontWeight.toSystem())
                    model.remoteSceneSettingsUpdated()
                }
            }
            Toggle("Monospaced digits", isOn: $text.fontMonospacedDigits)
                .onChange(of: text.fontMonospacedDigits) { _ in
                    model.getTextEffect(id: widget.id)?.setFontMonospacedDigits(enabled: text.fontMonospacedDigits)
                    model.remoteSceneSettingsUpdated()
                }
        } header: {
            Text("Font")
        }
        Section {
            HStack {
                Text("Alignment")
                Spacer()
                Picker("", selection: $text.horizontalAlignment) {
                    ForEach(SettingsHorizontalAlignment.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: text.horizontalAlignment) { _ in
                    model.getTextEffect(id: widget.id)?
                        .setHorizontalAlignment(alignment: text.horizontalAlignment.toSystem())
                    model.remoteSceneSettingsUpdated()
                }
            }
        }
        Section {
            HStack {
                Slider(
                    value: $text.delay,
                    in: 0 ... 10,
                    step: 0.5,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.resetSelectedScene(changeScene: false)
                    }
                )
                Text(String(String(text.delay)))
                    .frame(width: 35)
            }
        } header: {
            Text("Delay")
        } footer: {
            Text("To show the widget in sync with high latency cameras.")
        }
    }
}
