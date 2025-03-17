import PhotosUI
import SwiftUI

private struct Suggestion: Identifiable {
    var id: Int
    var name: String
    var text: String
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
private let suggestionWeather = "{conditions} {temperature}"
private let suggestionTravel =
    "\(suggestionWeather)\n\(suggestionTime)\n\(suggestionCity)\n\(suggestionMovement)"
private let suggestionDebug = "{time}\n{bitrateAndTotal}\n{debugOverlay}"
private let suggestionWorkoutTest = "{activeEnergyBurned} {power} {stepCount} {workoutDistance}"
private let suggestionTesla = "🚗 Tesla\n⚙️ {teslaDrive}\n🔋 {teslaBatteryLevel}\n🔈 {teslaMedia}"

private let suggestions = createSuggestions()

private func createSuggestions() -> [Suggestion] {
    var suggestions = [
        Suggestion(id: 0, name: String(localized: "Travel"), text: suggestionTravel),
        Suggestion(id: 1, name: String(localized: "Weather"), text: suggestionWeather),
        Suggestion(id: 2, name: String(localized: "Time"), text: suggestionTime),
        Suggestion(id: 3, name: String(localized: "Date"), text: suggestionDate),
        Suggestion(id: 4, name: String(localized: "Full date"), text: suggestionFullDate),
        Suggestion(id: 5, name: String(localized: "Timer"), text: suggestionTimer),
        Suggestion(id: 6, name: String(localized: "City"), text: suggestionCity),
        Suggestion(id: 7, name: String(localized: "Country"), text: suggestionCountry),
        Suggestion(id: 8, name: String(localized: "Movement"), text: suggestionMovement),
    ]
    if isPhone() {
        suggestions += [
            Suggestion(id: 9, name: String(localized: "Heart rate"), text: suggestionHeartRate),
        ]
    }
    suggestions += [
        Suggestion(id: 10, name: String(localized: "Subtitles"), text: suggestionSubtitles),
        Suggestion(id: 11, name: String(localized: "Muted"), text: suggestionMuted),
        Suggestion(id: 12, name: String(localized: "Debug"), text: suggestionDebug),
        Suggestion(id: 13, name: String(localized: "Workout test"), text: suggestionWorkoutTest),
        Suggestion(id: 14, name: String(localized: "Tesla"), text: suggestionTesla),
    ]
    return suggestions
}

private struct SuggestionsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var value: String

    var body: some View {
        Form {
            Section {
                ForEach(suggestions) { suggestion in
                    VStack(alignment: .leading) {
                        Button {
                            value = suggestion.text
                            dismiss()
                        } label: {
                            Text(suggestion.name)
                                .font(.title3)
                        }
                        Text(suggestion.text)
                    }
                    .tag(suggestion.id)
                }
            }
        }
        .navigationTitle("Suggestions")
    }
}

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0

    private func updateTimers(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfTimers = parts.filter { value in
            switch value {
            case .timer:
                return true
            default:
                return false
            }
        }.count
        for index in 0 ..< numberOfTimers where index >= widget.text.timers!.count {
            widget.text.timers!.append(.init())
        }
        while widget.text.timers!.count > numberOfTimers {
            widget.text.timers!.removeLast()
        }
        textEffect?.setTimersEndTime(endTimes: widget.text.timers!.map {
            .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
        })
    }

    private func updateCheckboxes(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfCheckboxes = parts.filter { value in
            switch value {
            case .checkbox:
                return true
            default:
                return false
            }
        }.count
        for index in 0 ..< numberOfCheckboxes where index >= widget.text.checkboxes!.count {
            widget.text.checkboxes!.append(.init())
        }
        while widget.text.checkboxes!.count > numberOfCheckboxes {
            widget.text.checkboxes!.removeLast()
        }
        textEffect?.setCheckboxes(checkboxes: widget.text.checkboxes!.map { $0.checked })
    }

    private func updateRatings(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfRatings = parts.filter { value in
            switch value {
            case .rating:
                return true
            default:
                return false
            }
        }.count
        for index in 0 ..< numberOfRatings where index >= widget.text.ratings!.count {
            widget.text.ratings!.append(.init())
        }
        while widget.text.ratings!.count > numberOfRatings {
            widget.text.ratings!.removeLast()
        }
        textEffect?.setRatings(ratings: widget.text.ratings!.map { $0.rating })
    }

    private func updateLapTimes(_ textEffect: TextEffect?, _ parts: [TextFormatPart]) {
        let numberOfLapTimes = parts.filter { value in
            switch value {
            case .lapTimes:
                return true
            default:
                return false
            }
        }.count
        for index in 0 ..< numberOfLapTimes where index >= widget.text.lapTimes!.count {
            widget.text.lapTimes!.append(.init())
        }
        while widget.text.lapTimes!.count > numberOfLapTimes {
            widget.text.lapTimes!.removeLast()
        }
        textEffect?.setLapTimes(lapTimes: widget.text.lapTimes!.map { $0.lapTimes })
    }

    private func updateNeedsWeather(_ parts: [TextFormatPart]) {
        widget.text.needsWeather = !parts.filter { value in
            switch value {
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
        widget.text.needsGeography = !parts.filter { value in
            switch value {
            case .country:
                return true
            case .countryFlag:
                return true
            case .city:
                return true
            default:
                return false
            }
        }.isEmpty
        model.startGeographyManager()
    }

    private func updateNeedsSubtitles(_ parts: [TextFormatPart]) {
        widget.text.needsSubtitles = !parts.filter { value in
            switch value {
            case .subtitles:
                return true
            default:
                return false
            }
        }.isEmpty
        model.reloadSpeechToText()
    }

    private func update() {
        widget.text.formatString = value
        let textEffect = model.getTextEffect(id: widget.id)
        textEffect?.setFormat(format: value)
        let parts = loadTextFormat(format: value)
        updateTimers(textEffect, parts)
        updateCheckboxes(textEffect, parts)
        updateRatings(textEffect, parts)
        updateLapTimes(textEffect, parts)
        updateNeedsWeather(parts)
        updateNeedsGeography(parts)
        updateNeedsSubtitles(parts)
        model.sceneUpdated()
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $value, axis: .vertical)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            Section {
                NavigationLink {
                    SuggestionsView(value: $value)
                } label: {
                    Text("Suggestions")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("")
                    Text("General").bold()
                    Text("{time} - Show time as HH:MM:SS")
                    Text("{shortTime} - Show time as HH:MM")
                    Text("{date} - Show date")
                    Text("{fullDate} - Show full date")
                    Text("{timer} - Show a timer")
                    Text("{checkbox} - Show a checkbox")
                    Text("{rating} - Show a 0-5 rating")
                    Text("{subtitles} - Show subtitles")
                    Text("{lapTimes} - Show lap times")
                    Text("{muted} - Show muted")
                    Text("")
                    Text("Location (if Settings -> Location is enabled)").bold()
                    Text("{speed} - Show speed")
                    Text("{averageSpeed} - Show average speed")
                    Text("{altitude} - Show altitude")
                    Text("{distance} - Show distance")
                    Text("{slope} - Show slope")
                    Text("")
                    Text("Weather (if Settings -> Location is enabled)").bold()
                    Text("{conditions} - Show conditions")
                    Text("{temperature} - Show temperature")
                    Text("")
                    Text("Workout").bold()
                    if isPhone() {
                        Text("{heartRate} - Show Apple Watch heart rate")
                    }
                    Text("{heartRate:My device} - Show heart rate for heart rate device called \"My device\"")
                    Text("")
                    Text("Tesla (requires a Tesla)").bold()
                    Text("{teslaBatteryLevel} - Tesla battery level")
                    Text("")
                    Text("Cycling (requires a compatible bike)").bold()
                    Text("{cyclingPower} - Cycling power")
                    Text("{cyclingCadence} - Cycling cadence")
                    Text("")
                    Text("Debug").bold()
                    Text("{bitrateAndTotal} - Show bitrate and total number of bytes sent")
                    Text("{debugOverlay} - Show debug overlay (if enabled)")
                }
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
    var widget: SettingsWidget
    @State var backgroundColor: Color
    @State var foregroundColor: Color
    @State var fontSize: Float
    @State var fontDesign: String
    @State var fontWeight: String
    @State var horizontalAlignment: String
    @State var verticalAlignment: String
    @State var delay: Double

    var body: some View {
        Section {
            NavigationLink {
                TextSelectionView(widget: widget, value: widget.text.formatString)
            } label: {
                TextItemView(name: String(localized: "Text"), value: widget.text.formatString)
            }
        }
        if !widget.text.timers!.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(widget.text.timers!) { timer in
                        let index = widget.text.timers!.firstIndex(where: { $0 === timer }) ?? 0
                        TimerWidgetView(
                            name: "Timer \(index + 1)",
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
        if !widget.text.checkboxes!.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                let textFormat = loadTextFormat(format: widget.text.formatString)
                Section {
                    ForEach(widget.text.checkboxes!) { checkbox in
                        let index = widget.text.checkboxes!.firstIndex(where: { $0 === checkbox }) ?? 0
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
        if !widget.text.ratings!.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(widget.text.ratings!) { rating in
                        let index = widget.text.ratings!.firstIndex(where: { $0 === rating }) ?? 0
                        RatingWidgetView(
                            name: "Rating \(index + 1)",
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
        if !widget.text.lapTimes!.isEmpty {
            if let textEffect = model.getTextEffect(id: widget.id) {
                Section {
                    ForEach(widget.text.lapTimes!) { lapTimes in
                        let index = widget.text.lapTimes!.firstIndex(where: { $0 === lapTimes }) ?? 0
                        LapTimesWidgetView(
                            name: "Lap times \(index + 1)",
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
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: true)
                .onChange(of: backgroundColor) { _ in
                    guard let color = backgroundColor.toRgb() else {
                        return
                    }
                    widget.text.backgroundColor = color
                    model.getTextEffect(id: widget.id)?.setBackgroundColor(color: color)
                }
            ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: true)
                .onChange(of: foregroundColor) { _ in
                    guard let color = foregroundColor.toRgb() else {
                        return
                    }
                    widget.text.foregroundColor = color
                    model.getTextEffect(id: widget.id)?.setForegroundColor(color: color)
                }
        } header: {
            Text("Colors")
        }
        Section {
            HStack {
                Text("Size")
                Slider(
                    value: $fontSize,
                    in: 10 ... 200,
                    step: 5,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.text.fontSize = Int(fontSize)
                        model.getTextEffect(id: widget.id)?.setFontSize(size: CGFloat(fontSize))
                    }
                )
                Text(String(Int(fontSize)))
                    .frame(width: 35)
            }
            HStack {
                Text("Design")
                Spacer()
                Picker("", selection: $fontDesign) {
                    ForEach(textWidgetFontDesigns, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: fontDesign) {
                    widget.text.fontDesign = SettingsFontDesign.fromString(value: $0)
                    model.getTextEffect(id: widget.id)?
                        .setFontDesign(design: widget.text.fontDesign!.toSystem())
                }
            }
            HStack {
                Text("Weight")
                Spacer()
                Picker("", selection: $fontWeight) {
                    ForEach(textWidgetFontWeights, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: fontWeight) {
                    widget.text.fontWeight = SettingsFontWeight.fromString(value: $0)
                    model.getTextEffect(id: widget.id)?
                        .setFontWeight(weight: widget.text.fontWeight!.toSystem())
                }
            }
        } header: {
            Text("Font")
        }
        Section {
            HStack {
                Text("Horizontal")
                Spacer()
                Picker("", selection: $horizontalAlignment) {
                    ForEach(textWidgetHorizontalAlignments, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: horizontalAlignment) {
                    widget.text.horizontalAlignment = SettingsHorizontalAlignment.fromString(value: $0)
                    model.getTextEffect(id: widget.id)?
                        .setHorizontalAlignment(alignment: widget.text.horizontalAlignment!.toSystem())
                }
            }
            HStack {
                Text("Vertical")
                Spacer()
                Picker("", selection: $verticalAlignment) {
                    ForEach(textWidgetVerticalAlignments, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: verticalAlignment) {
                    widget.text.verticalAlignment = SettingsVerticalAlignment.fromString(value: $0)
                    model.getTextEffect(id: widget.id)?
                        .setVerticalAlignment(alignment: widget.text.verticalAlignment!.toSystem())
                }
            }
        } header: {
            Text("Alignment")
        }
        Section {
            HStack {
                Slider(
                    value: $delay,
                    in: 0 ... 10,
                    step: 0.5,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.text.delay = delay
                        model.resetSelectedScene(changeScene: false)
                    }
                )
                Text(String(String(delay)))
                    .frame(width: 35)
            }
        } header: {
            Text("Delay")
        } footer: {
            Text("To show the widget in sync with high latency cameras.")
        }
    }
}
