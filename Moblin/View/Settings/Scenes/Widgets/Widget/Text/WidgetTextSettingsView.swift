import PhotosUI
import SwiftUI

struct WidgetTextSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var backgroundColor: Color
    @State var foregroundColor: Color
    @State var fontSize: Float

    private func submitFormatString(value: String) {
        widget.text.formatString = value
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            TextEditNavigationView(
                title: String(localized: "Text"),
                value: widget.text.formatString,
                onSubmit: submitFormatString,
                footers: [
                    String(localized: "{time} - Show time as HH:MM:SS"),
                    String(localized: "{speed} - Show speed (if Settings → Location is enabled)"),
                    String(localized: "{altitude} - Show altitude (if Settings → Location is enabled)"),
                    String(localized: "{distance} - Show distance (if Settings → Location is enabled)"),
                    String(localized: "{bitrateAndTotal} - Show bitrate and total number of bytes sent"),
                    String(localized: "{debugOverlay} - Show debug overlay (if enabled)"),
                ]
            )
        }
        Section {
            Toggle(isOn: Binding(get: {
                !widget.text.clearBackgroundColor!
            }, set: { value in
                widget.text.clearBackgroundColor = !value
                model.store()
                model.resetSelectedScene(changeScene: false)
            })) {
                ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                    .onChange(of: backgroundColor) { _ in
                        guard let color = backgroundColor.toRgb() else {
                            return
                        }
                        widget.text.backgroundColor = color
                        model.store()
                        model.resetSelectedScene(changeScene: false)
                    }
            }
            Toggle(isOn: Binding(get: {
                !widget.text.clearForegroundColor!
            }, set: { value in
                widget.text.clearForegroundColor = !value
                model.store()
                model.resetSelectedScene(changeScene: false)
            })) {
                ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: false)
                    .onChange(of: foregroundColor) { _ in
                        guard let color = foregroundColor.toRgb() else {
                            return
                        }
                        widget.text.foregroundColor = color
                        model.store()
                        model.resetSelectedScene(changeScene: false)
                    }
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
        .onDisappear {
            model.store()
        }
    }
}
