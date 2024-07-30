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
private let suggestionTime = "🕑 {time}"
private let suggestionTimer = "⏳ {timer}"
private let suggestionWeather = "{conditions} {temperature}"
private let suggestionTravel =
    "\(suggestionWeather)\n\(suggestionTime)\n\(suggestionCity)\n\(suggestionMovement)"
private let suggestionDebug = "{time}\n{bitrateAndTotal}\n{debugOverlay}"

private let suggestions = [
    Suggestion(id: 0, name: String(localized: "Travel"), text: suggestionTravel),
    Suggestion(id: 1, name: String(localized: "Weather"), text: suggestionWeather),
    Suggestion(id: 2, name: String(localized: "Time"), text: suggestionTime),
    Suggestion(id: 3, name: String(localized: "Timer"), text: suggestionTimer),
    Suggestion(id: 4, name: String(localized: "City"), text: suggestionCity),
    Suggestion(id: 5, name: String(localized: "Country"), text: suggestionCountry),
    Suggestion(id: 6, name: String(localized: "Movement"), text: suggestionMovement),
    Suggestion(id: 7, name: String(localized: "Debug"), text: suggestionDebug),
]

private struct SuggestionsView: View {
    @Environment(\.dismiss) var dismiss
    @State var suggestion: Int = 0
    var onSubmit: (String) -> Void

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading) {
                            Button {
                                onSubmit(suggestion.text)
                                dismiss()
                            } label: {
                                Text(suggestion.name).font(.title3)
                            }
                            Text(suggestion.text)
                        }
                        .tag(suggestion.id)
                    }
                }
            }
        }
        .navigationTitle("Suggestions")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0
    @FocusState private var isFocused: Bool

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

    private func update() {
        widget.text.formatString = value
        let textEffect = model.getTextEffect(id: widget.id)
        textEffect?.setFormat(format: value)
        let parts = loadTextFormat(format: value)
        updateTimers(textEffect, parts)
        updateCheckboxes(textEffect, parts)
        updateNeedsWeather(parts)
        updateNeedsGeography(parts)
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $value, axis: .vertical)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        update()
                    }
                    .focused($isFocused)
                if isFocused {
                    Button {
                        isFocused = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Done")
                        }
                    }
                }
            }
            Section {
                NavigationLink(destination: SuggestionsView(onSubmit: { value in
                    self.value = value
                    update()
                })) {
                    Text("Suggestions")
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("")
                    Text("General").bold()
                    Text("{time} - Show time as HH:MM:SS")
                    Text("{timer} - Show a timer")
                    Text("{checkbox} - Show a checkbox")
                    Text("")
                    Text("Location (if Settings -> Location is enabled)").bold()
                    Text("{speed} - Show speed")
                    Text("{altitude} - Show altitude")
                    Text("{distance} - Show distance")
                    Text("")
                    Text("Weather (if Settings -> Location is enabled)").bold()
                    Text("{conditions} - Show conditions")
                    Text("{temperature} - Show temperature")
                    Text("")
                    Text("Debug").bold()
                    Text("{bitrateAndTotal} - Show bitrate and total number of bytes sent")
                    Text("{debugOverlay} - Show debug overlay (if enabled)")
                }
            }
        }
        .navigationTitle("Text")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct WidgetTextSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var backgroundColor: Color
    @State var foregroundColor: Color
    @State var fontSize: Float
    @State var delay: Double

    var body: some View {
        Section {
            NavigationLink(destination: TextSelectionView(widget: widget, value: widget.text.formatString)) {
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
                Section {
                    ForEach(widget.text.checkboxes!) { checkbox in
                        let index = widget.text.checkboxes!.firstIndex(where: { $0 === checkbox }) ?? 0
                        CheckboxWidgetView(
                            name: "Checkbox \(index + 1)",
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
                Picker("", selection: Binding(get: {
                    widget.text.fontDesign!.toString()
                }, set: { value in
                    widget.text.fontDesign = SettingsFontDesign.fromString(value: value)
                    model.getTextEffect(id: widget.id)?
                        .setFontDesign(design: widget.text.fontDesign!.toSystem())
                })) {
                    ForEach(textWidgetFontDesigns, id: \.self) {
                        Text($0)
                    }
                }
            }
            HStack {
                Text("Weight")
                Spacer()
                Picker("", selection: Binding(get: {
                    widget.text.fontWeight!.toString()
                }, set: { value in
                    widget.text.fontWeight = SettingsFontWeight.fromString(value: value)
                    model.getTextEffect(id: widget.id)?
                        .setFontWeight(weight: widget.text.fontWeight!.toSystem())
                })) {
                    ForEach(textWidgetFontWeights, id: \.self) {
                        Text($0)
                    }
                }
            }
        } header: {
            Text("Font")
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
        .onDisappear {
            model.store()
        }
    }
}
