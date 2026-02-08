import PhotosUI
import SwiftUI
import Translation

private struct Suggestion: Identifiable {
    let id: Int
    let name: LocalizedStringKey
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
        Suggestion(id: 0, name: "Travel", text: suggestionTravel),
        Suggestion(id: 1, name: "Weather", text: suggestionWeather),
        Suggestion(id: 2, name: "Time", text: suggestionTime),
        Suggestion(id: 3, name: "Date", text: suggestionDate),
        Suggestion(id: 4, name: "Full date", text: suggestionFullDate),
        Suggestion(id: 5, name: "Timer", text: suggestionTimer),
        Suggestion(id: 6, name: "Stopwatch", text: suggestionStopwatch),
        Suggestion(id: 7, name: "City", text: suggestionCity),
        Suggestion(id: 8, name: "Country", text: suggestionCountry),
        Suggestion(id: 9, name: "Movement", text: suggestionMovement),
    ]
    if isPhone() {
        suggestions += [
            Suggestion(id: 10, name: "Heart rate", text: suggestionHeartRate),
        ]
    }
    suggestions += [
        Suggestion(id: 11, name: "Subtitles", text: suggestionSubtitles),
        Suggestion(id: 12, name: "Muted", text: suggestionMuted),
        Suggestion(id: 13, name: "Debug", text: suggestionDebug),
        Suggestion(id: 14, name: "Workout test", text: suggestionWorkoutTest),
        Suggestion(id: 15, name: "Tesla", text: suggestionTesla),
        Suggestion(id: 16, name: "Racing", text: suggestionRacing),
    ]
    return suggestions
}

private struct SuggestionView: View {
    let suggestion: Suggestion
    @Binding var text: String
    let dismiss: () -> Void
    @State private var presentingConfirmation = false

    private func submit() {
        text = suggestion.text
        dismiss()
    }

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                if text.isEmpty {
                    submit()
                } else {
                    presentingConfirmation = true
                }
            } label: {
                Text(suggestion.name)
                    .font(.title3)
            }
            .confirmationDialog("", isPresented: $presentingConfirmation) {
                Button("Yes", role: .destructive) {
                    submit()
                }
            } message: {
                Text("Are you sure you want to replace the content of the current text widget?")
            }
            Text(suggestion.text)
        }
    }
}

private struct VariableView: View {
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

@available(iOS 26, *)
private struct Language: Identifiable {
    var id: String {
        identifier
    }

    var identifier: String
    var name: String
    var status: LanguageAvailability.Status
}

@available(iOS 26, *)
private struct SubtitlesWithLanguageView: View {
    @EnvironmentObject var model: Model
    @Binding var text: String
    @State private var languages: [Language] = []
    @State private var presentingLanguagePicker: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                presentingLanguagePicker = true
            } label: {
                Text("{subtitles:<language-identifier>}")
                    .font(.title3)
            }
            Text("Show subtitles in given language")
        }
        .sheet(isPresented: $presentingLanguagePicker) {
            NavigationStack {
                Form {
                    Section {
                        Text("Download languages in iOS Settings → Apps → Translate → Languages.")
                    }
                    Section {
                        ForEach(languages) { language in
                            switch language.status {
                            case .installed:
                                Button {
                                    let value = "{subtitles:\(language.identifier)}"
                                    text += value
                                    model.makeToast(title: "Appended \(value) to widget text")
                                    presentingLanguagePicker = false
                                } label: {
                                    Text(language.name)
                                }
                            case .supported:
                                HStack {
                                    Text(language.name)
                                    Spacer()
                                    Text("Not downloaded")
                                }
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                .navigationTitle("Subtitles language")
                .toolbar {
                    CloseToolbar(presenting: $presentingLanguagePicker)
                }
                .task {
                    let availability = LanguageAvailability()
                    let supportedLanguages = await availability.supportedLanguages
                    languages = []
                    for language in supportedLanguages {
                        let status = await availability.status(from: Locale.current.language, to: language)
                        languages.append(Language(identifier: language.minimalIdentifier,
                                                  name: language.name(),
                                                  status: status))
                    }
                    languages = languages.sorted(by: { $0.id < $1.id })
                }
            }
        }
    }
}

struct TimeComponentPickerView: View {
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

struct TimeButtonView: View {
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

private struct TimerWidgetView: View {
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
                HStack(spacing: 13) {
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
                        Image(systemName: "minus")
                            .font(.title)
                    }
                    Button {
                        timer.add(delta: 60 * Double(timer.delta))
                        updateTextEffect()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title)
                    }
                    Button {
                        presentingSetTime = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                    }
                    .popover(isPresented: $presentingSetTime) {
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

private struct StopwatchWidgetView: View {
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
                HStack(spacing: 13) {
                    Spacer()
                    Button {
                        presentingSetTime = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title)
                    }
                    .popover(isPresented: $presentingSetTime) {
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

private struct CheckboxWidgetView: View {
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

private struct RatingWidgetView: View {
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

private struct LapTimesWidgetView: View {
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
        HStack(spacing: 13) {
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
                    .tint(.red)
            }
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

private struct TextWidgetSuggestionsInnerView: View {
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

private struct GeneralVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(
                    title: "{checkbox}",
                    description: String(localized: "Show a checkbox"),
                    text: $value
                )
                VariableView(
                    title: "{rating}",
                    description: String(localized: "Show a 0-5 rating"),
                    text: $value
                )
                VariableView(title: "{muted}", description: String(localized: "Show muted"), text: $value)
                VariableView(
                    title: "{browserTitle}",
                    description: String(localized: "Show browser title"),
                    text: $value
                )
                VariableView(title: "{gForce}", description: String(localized: "Show G-force"), text: $value)
                VariableView(
                    title: "{gForceRecentMax}",
                    description: String(localized: "Show recent max G-force"),
                    text: $value
                )
                VariableView(
                    title: "{gForceMax}",
                    description: String(localized: "Show max G-force"),
                    text: $value
                )
            }
            .navigationTitle("General")
        } label: {
            Text("General")
        }
    }
}

private struct TimeVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                let now = Date()
                let time = now.formatted(textEffectTimeFormat)
                VariableView(
                    title: "{time}",
                    description: String(localized: "Show time as \(time)"),
                    text: $value
                )
                let shortTime = now.formatted(textEffectShortTimeFormat)
                VariableView(
                    title: "{shortTime}",
                    description: String(localized: "Show time as \(shortTime)"),
                    text: $value
                )
                let date = textEffectDateFormatter.string(from: now)
                VariableView(title: "{date}",
                             description: String(localized: "Show date as \(date)"),
                             text: $value)
                let fullDate = textEffectFullDateFormatter.string(from: now)
                VariableView(title: "{fullDate}",
                             description: String(localized: "Show date as \(fullDate)"),
                             text: $value)
                VariableView(title: "{timer}", description: String(localized: "Show a timer"), text: $value)
                VariableView(
                    title: "{stopwatch}",
                    description: String(localized: "Show a stopwatch"),
                    text: $value
                )
                VariableView(
                    title: "{lapTimes}",
                    description: String(localized: "Show lap times"),
                    text: $value
                )
            }
            .navigationTitle("Time")
        } label: {
            Text("Time")
        }
    }
}

private struct LocationVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(title: "{country}", description: String(localized: "Show country"), text: $value)
                VariableView(
                    title: "{countryFlag}",
                    description: String(localized: "Show country flag"),
                    text: $value
                )
                VariableView(title: "{state}", description: String(localized: "Show state"), text: $value)
                VariableView(title: "{city}", description: String(localized: "Show city"), text: $value)
                VariableView(title: "{speed}", description: String(localized: "Show speed"), text: $value)
                VariableView(
                    title: "{averageSpeed}",
                    description: String(localized: "Show average speed"),
                    text: $value
                )
                VariableView(
                    title: "{altitude}",
                    description: String(localized: "Show altitude"),
                    text: $value
                )
                VariableView(
                    title: "{distance}",
                    description: String(localized: "Show distance"),
                    text: $value
                )
                VariableView(title: "{slope}", description: String(localized: "Show slope"), text: $value)
            }
            .navigationTitle("Location")
        } label: {
            Text("Location")
        }
    }
}

private struct WeatherVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    VariableView(
                        title: "{conditions}",
                        description: String(localized: "Show conditions"),
                        text: $value
                    )
                    VariableView(
                        title: "{temperature}",
                        description: String(localized: "Show temperature"),
                        text: $value
                    )
                    VariableView(
                        title: "{feelsLikeTemperature}",
                        description: String(localized: "Show feels like temperature"),
                        text: $value
                    )
                    VariableView(
                        title: "{wind}",
                        description: String(localized: "Show wind"),
                        text: $value
                    )
                } footer: {
                    let image = Image(systemName: "apple.logo")
                    Text("""
                    Weather data is provided by \(image) Weather. \
                    [Legal information](https://weatherkit.apple.com/legal-attribution.html).
                    """)
                }
            }
            .navigationTitle("Weather")
        } label: {
            Text("Weather")
        }
    }
}

private struct LanguageVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(
                    title: "{subtitles}",
                    description: String(localized: "Show subtitles in app language"),
                    text: $value
                )
                if #available(iOS 26, *) {
                    SubtitlesWithLanguageView(text: $value)
                }
            }
            .navigationTitle("Language")
        } label: {
            Text("Language")
        }
    }
}

private struct WorkoutVariablesView: View {
    let model: Model
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                if isPhone() {
                    VariableView(
                        title: "{heartRate}",
                        description: String(localized: "Show Apple Watch heart rate"),
                        text: $value
                    )
                }
                ForEach(model.database.workoutDevices.devices) { device in
                    VariableView(
                        title: "{heartRate:\(device.name)}",
                        description: String(
                            localized: "Show heart rate for heart rate device called \"\(device.name)\""
                        ),
                        text: $value
                    )
                }
                VariableView(
                    title: "{cyclingPower}",
                    description: String(localized: "Show cycling power"),
                    text: $value
                )
                VariableView(
                    title: "{cyclingCadence}",
                    description: String(localized: "Show cycling cadence"),
                    text: $value
                )
            }
            .navigationTitle("Workout")
        } label: {
            Text("Workout")
        }
    }
}

private struct TeslaVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(
                    title: "{teslaBatteryLevel}",
                    description: String(localized: "Show Tesla battery level"),
                    text: $value
                )
                VariableView(
                    title: "{teslaDrive}",
                    description: String(localized: "Show Tesla drive information"),
                    text: $value
                )
                VariableView(
                    title: "{teslaMedia}",
                    description: String(localized: "Show Tesla media information"),
                    text: $value
                )
            }
            .navigationTitle("Tesla")
        } label: {
            Text("Tesla")
        }
    }
}

private struct DebugVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(
                    title: "{bitrate}",
                    description: String(localized: "Show bitrate"),
                    text: $value
                )
                VariableView(
                    title: "{bitrateAndTotal}",
                    description: String(localized: "Show bitrate and total number of bytes sent"),
                    text: $value
                )
                VariableView(
                    title: "{resolution}",
                    description: String(localized: "Show resolution"),
                    text: $value
                )
                VariableView(
                    title: "{fps}",
                    description: String(localized: "Show FPS"),
                    text: $value
                )
                VariableView(
                    title: "{debugOverlay}",
                    description: String(localized: "Show debug overlay (if enabled)"),
                    text: $value
                )
            }
            .navigationTitle("Debug")
        } label: {
            Text("Debug")
        }
    }
}

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    let widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0

    var body: some View {
        Form {
            TextWidgetTextView(value: $value)
            Section {
                TextWidgetSuggestionsView(text: $value)
            }
            Section {
                GeneralVariablesView(value: $value)
                TimeVariablesView(value: $value)
                LocationVariablesView(value: $value)
                WeatherVariablesView(value: $value)
                LanguageVariablesView(value: $value)
                WorkoutVariablesView(model: model, value: $value)
                TeslaVariablesView(value: $value)
                DebugVariablesView(value: $value)
            } header: {
                Text("Variables")
            }
        }
        .onChange(of: value) { _ in
            widget.text.formatString = value
            model.textWidgetTextChanged(widget: widget)
        }
        .navigationTitle("Text")
    }
}

struct TextWidgetTextView: View {
    @Binding var value: String
    @FocusState private var editingText: Bool

    var body: some View {
        Section {
            MultiLineTextFieldView(value: $value)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($editingText)
        } footer: {
            MultiLineTextFieldDoneButtonView(editingText: $editingText)
        }
    }
}

struct WidgetTextQuickButtonControlsView: View {
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

struct TextWidgetSuggestionsView: View {
    @Binding var text: String

    var body: some View {
        NavigationLink {
            TextWidgetSuggestionsInnerView(text: $text)
        } label: {
            Text("Suggestions")
        }
    }
}

struct WidgetTextSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var text: SettingsWidgetText

    private func changeWidth(value: String) -> String? {
        guard let width = Int(value) else {
            return String(localized: "Not a number")
        }
        guard width > 0 else {
            return String(localized: "Too small")
        }
        guard width < 4000 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        text.width = width
        setLayout()
    }

    private func changeCornerRadius(value: String) -> String? {
        guard let cornerRadius = Int(value) else {
            return String(localized: "Not a number")
        }
        guard cornerRadius >= 0 else {
            return String(localized: "Too small")
        }
        guard cornerRadius < 1000 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitCornerRadius(value: String) {
        guard let cornerRadius = Int(value) else {
            return
        }
        text.cornerRadius = cornerRadius
        setLayout()
    }

    private func setLayout() {
        for effect in model.getTextEffects(id: widget.id) {
            effect.setLayout(alignment: text.horizontalAlignment.toSystem(),
                             width: text.widthEnabled ? text.width : nil,
                             cornerRadius: Double(text.cornerRadius))
        }
        model.remoteSceneSettingsUpdated()
    }

    var body: some View {
        Section {
            NavigationLink {
                TextSelectionView(widget: widget, value: text.formatString)
            } label: {
                TextItemLocalizedView(name: "Text", value: widget.text.formatString)
            }
        }
        let textEffects = model.getTextEffects(id: widget.id)
        if !textEffects.isEmpty {
            if !text.timers.isEmpty {
                Section {
                    ForEach(text.timers) { timer in
                        let index = text.timers.firstIndex(where: { $0 === timer }) ?? 0
                        TimerWidgetView(
                            name: String(localized: "Timer \(index + 1)"),
                            timer: timer,
                            index: index,
                            textEffects: textEffects,
                            indented: false
                        )
                    }
                } header: {
                    Text("Timers")
                }
            }
            if !text.stopwatches.isEmpty {
                Section {
                    ForEach(text.stopwatches) { stopwatch in
                        let index = widget.text.stopwatches.firstIndex(where: { $0 === stopwatch }) ?? 0
                        StopwatchWidgetView(
                            name: String(localized: "Stopwatch \(index + 1)"),
                            stopwatch: stopwatch,
                            index: index,
                            textEffects: textEffects,
                            indented: false
                        )
                    }
                } header: {
                    Text("Stopwatches")
                }
            }
            if !text.checkboxes.isEmpty {
                let textFormat = loadTextFormat(format: text.formatString)
                Section {
                    ForEach(text.checkboxes) { checkbox in
                        let index = text.checkboxes.firstIndex(where: { $0 === checkbox }) ?? 0
                        CheckboxWidgetView(
                            name: textFormat.getCheckboxText(index: index),
                            checkbox: checkbox,
                            index: index,
                            textEffects: textEffects,
                            indented: false
                        )
                    }
                } header: {
                    Text("Checkboxes")
                }
            }
            if !text.ratings.isEmpty {
                Section {
                    ForEach(text.ratings) { rating in
                        let index = text.ratings.firstIndex(where: { $0 === rating }) ?? 0
                        RatingWidgetView(
                            name: String(localized: "Rating \(index + 1)"),
                            rating: rating,
                            index: index,
                            textEffects: textEffects,
                            indented: false
                        )
                    }
                } header: {
                    Text("Ratings")
                }
            }
            if !text.lapTimes.isEmpty {
                Section {
                    ForEach(text.lapTimes) { lapTimes in
                        let index = text.lapTimes.firstIndex(where: { $0 === lapTimes }) ?? 0
                        LapTimesWidgetView(
                            name: String(localized: "Lap times \(index + 1)"),
                            lapTimes: lapTimes,
                            index: index,
                            textEffects: textEffects,
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
                    for effect in model.getTextEffects(id: widget.id) {
                        effect.setBackgroundColor(color: color)
                    }
                    model.remoteSceneSettingsUpdated()
                }
            ColorPicker("Foreground", selection: $text.foregroundColorColor, supportsOpacity: true)
                .onChange(of: text.foregroundColorColor) { _ in
                    guard let color = text.foregroundColorColor.toRgb() else {
                        return
                    }
                    text.foregroundColor = color
                    for effect in model.getTextEffects(id: widget.id) {
                        effect.setForegroundColor(color: color)
                    }
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
                    for effect in model.getTextEffects(id: widget.id) {
                        effect.setFontSize(size: CGFloat(text.fontSizeFloat))
                    }
                    model.remoteSceneSettingsUpdated()
                }
                Text(String(Int(text.fontSizeFloat)))
                    .frame(width: 35)
            }
            Picker("Design", selection: $text.fontDesign) {
                ForEach(SettingsFontDesign.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: text.fontDesign) { _ in
                for effect in model.getTextEffects(id: widget.id) {
                    effect.setFontDesign(design: text.fontDesign.toSystem())
                }
                model.remoteSceneSettingsUpdated()
            }
            Picker("Weight", selection: $text.fontWeight) {
                ForEach(SettingsFontWeight.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: text.fontWeight) { _ in
                for effect in model.getTextEffects(id: widget.id) {
                    effect.setFontWeight(weight: text.fontWeight.toSystem())
                }
                model.remoteSceneSettingsUpdated()
            }
            Toggle("Monospaced digits", isOn: $text.fontMonospacedDigits)
                .onChange(of: text.fontMonospacedDigits) { _ in
                    for effect in model.getTextEffects(id: widget.id) {
                        effect.setFontMonospacedDigits(enabled: text.fontMonospacedDigits)
                    }
                    model.remoteSceneSettingsUpdated()
                }
        } header: {
            Text("Font")
        }
        Section {
            Picker("Alignment", selection: $text.horizontalAlignment) {
                ForEach(SettingsHorizontalAlignment.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: text.horizontalAlignment) { _ in
                setLayout()
            }
            NavigationLink {
                TextEditView(
                    title: String(localized: "Minimum width"),
                    value: String(text.width),
                    keyboardType: .numbersAndPunctuation,
                    onChange: changeWidth,
                    onSubmit: submitWidth
                )
            } label: {
                HStack {
                    Text("Minimum width")
                    Spacer(minLength: 0)
                    Toggle(isOn: $text.widthEnabled) {}
                        .padding([.trailing], 2)
                    GrayTextView(text: String(text.width))
                }
                .onChange(of: text.widthEnabled) { _ in
                    setLayout()
                }
            }
            TextEditNavigationView(
                title: String(localized: "Corner radius"),
                value: String(text.cornerRadius),
                onChange: changeCornerRadius,
                onSubmit: submitCornerRadius,
                keyboardType: .numbersAndPunctuation
            )
        } header: {
            Text("Layout")
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
