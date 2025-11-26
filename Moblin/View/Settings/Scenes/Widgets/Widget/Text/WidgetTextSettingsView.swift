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
    @State private var isPresentingConfirmation = false

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
                    isPresentingConfirmation = true
                }
            } label: {
                Text(suggestion.name)
                    .font(.title3)
            }
            .confirmationDialog("", isPresented: $isPresentingConfirmation) {
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

private struct SubtitlesWithLanguageToolbar: ToolbarContent {
    @Binding var presentingLanguagePicker: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                presentingLanguagePicker = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
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
                    SubtitlesWithLanguageToolbar(presentingLanguagePicker: $presentingLanguagePicker)
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

private struct GeneralVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
                VariableView(title: "{checkbox}", description: String(localized: "Show a checkbox"), text: $value)
                VariableView(title: "{rating}", description: String(localized: "Show a 0-5 rating"), text: $value)
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
                VariableView(
                    title: "{time}",
                    description: String(localized: "Show time as HH:MM:SS"),
                    text: $value
                )
                VariableView(
                    title: "{shortTime}",
                    description: String(localized: "Show time as HH:MM"),
                    text: $value
                )
                VariableView(title: "{date}", description: String(localized: "Show date"), text: $value)
                VariableView(title: "{fullDate}", description: String(localized: "Show full date"), text: $value)
                VariableView(title: "{timer}", description: String(localized: "Show a timer"), text: $value)
                VariableView(
                    title: "{stopwatch}",
                    description: String(localized: "Show a stopwatch"),
                    text: $value
                )
                VariableView(title: "{lapTimes}", description: String(localized: "Show lap times"), text: $value)
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
                VariableView(title: "{altitude}", description: String(localized: "Show altitude"), text: $value)
                VariableView(title: "{distance}", description: String(localized: "Show distance"), text: $value)
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
                ForEach(model.database.heartRateDevices.devices) { device in
                    VariableView(
                        title: "{heartRate:\(device.name)}",
                        description: String(
                            localized: "Show heart rate for heart rate device called \"\(device.name)\""
                        ),
                        text: $value
                    )
                }
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

private struct CyclingVariablesView: View {
    @Binding var value: String

    var body: some View {
        NavigationLink {
            Form {
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
            .navigationTitle("Cycling")
        } label: {
            Text("Cycling")
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

struct TextWidgetTextView: View {
    @Binding var value: String
    @FocusState var editingText: Bool

    var body: some View {
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
    }
}

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    let widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0
    @FocusState var editingText: Bool

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
                CyclingVariablesView(value: $value)
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
            Picker("Design", selection: $text.fontDesign) {
                ForEach(SettingsFontDesign.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: text.fontDesign) { _ in
                model.getTextEffect(id: widget.id)?.setFontDesign(design: text.fontDesign.toSystem())
                model.remoteSceneSettingsUpdated()
            }
            Picker("Weight", selection: $text.fontWeight) {
                ForEach(SettingsFontWeight.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: text.fontWeight) { _ in
                model.getTextEffect(id: widget.id)?.setFontWeight(weight: text.fontWeight.toSystem())
                model.remoteSceneSettingsUpdated()
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
            Picker("Alignment", selection: $text.horizontalAlignment) {
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
