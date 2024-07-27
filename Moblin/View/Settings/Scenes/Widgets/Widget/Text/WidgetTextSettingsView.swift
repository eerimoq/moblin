import PhotosUI
import SwiftUI

private struct Suggestion: Identifiable {
    var id: Int
    var name: String
    var text: String
}

private let suggestions = [
    Suggestion(id: 0, name: "Select one", text: ""),
    Suggestion(id: 1, name: "Clock", text: "{time}"),
    Suggestion(id: 2, name: "Weather", text: "{conditions} {temperature}"),
    Suggestion(id: 3, name: "Timer", text: "⏳ {timer}"),
    Suggestion(id: 4, name: "Biking", text: "📏 {distance} 💨 {speed} 🏔️ {altitude}"),
]

private struct TextSelectionView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var widget: SettingsWidget
    @State var value: String
    @State var suggestion: Int = 0
    @State private var changed = false
    @State private var submitted = false

    private func submit() {
        submitted = true
        widget.text.formatString = value
        let parts = loadTextFormat(format: value)
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
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $value)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        changed = true
                    }
                    .onSubmit {
                        submit()
                        dismiss()
                    }
                    .submitLabel(.done)
                    .onDisappear {
                        if changed && !submitted {
                            submit()
                        }
                    }
                Picker("Suggestions", selection: $suggestion) {
                    ForEach(suggestions) { suggestion in
                        Text(suggestion.name).tag(suggestion.id)
                    }
                }
                .onChange(of: suggestion) { _ in
                    if suggestion != 0 {
                        value = suggestions[suggestion].text
                        changed = true
                    }
                    dismiss()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("General").bold()
                    Text("{time} - Show time as HH:MM:SS")
                    Text("{timer} - Show a timer")
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
        Section {
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: true)
                .onChange(of: backgroundColor) { _ in
                    guard let color = backgroundColor.toRgb() else {
                        return
                    }
                    widget.text.backgroundColor = color
                    guard let textEffect = model.getTextEffect(id: widget.id) else {
                        return
                    }
                    textEffect.setBackgroundColor(color: color)
                }
            ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: true)
                .onChange(of: foregroundColor) { _ in
                    guard let color = foregroundColor.toRgb() else {
                        return
                    }
                    widget.text.foregroundColor = color
                    guard let textEffect = model.getTextEffect(id: widget.id) else {
                        return
                    }
                    textEffect.setForegroundColor(color: color)
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
                        model.resetSelectedScene(changeScene: false)
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
                    model.resetSelectedScene(changeScene: false)
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
                    model.resetSelectedScene(changeScene: false)
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
