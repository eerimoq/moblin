import Foundation
import SwiftUI

struct AlertFontView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert
    @State var fontSize: Float
    @State var fontDesign: String
    @State var fontWeight: String

    var body: some View {
        Section {
            HStack {
                Text("Size")
                Slider(
                    value: $fontSize,
                    in: 10 ... 80,
                    step: 5
                )
                .onChange(of: fontSize) { value in
                    alert.fontSize = Int(value)
                    model.updateAlertsSettings()
                }
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
                    alert.fontDesign = SettingsFontDesign.fromString(value: $0)
                    model.updateAlertsSettings()
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
                    alert.fontWeight = SettingsFontWeight.fromString(value: $0)
                    model.updateAlertsSettings()
                }
            }
        } header: {
            Text("Font")
        }
    }
}

struct AlertColorsView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsAlert
    @State var textColor: Color
    @State var accentColor: Color

    var body: some View {
        Section {
            ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                .onChange(of: textColor) { color in
                    guard let color = color.toRgb() else {
                        return
                    }
                    alert.textColor = color
                    model.updateAlertsSettings()
                }
            ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                .onChange(of: accentColor) { color in
                    guard let color = color.toRgb() else {
                        return
                    }
                    alert.accentColor = color
                    model.updateAlertsSettings()
                }
        } header: {
            Text("Colors")
        }
    }
}
