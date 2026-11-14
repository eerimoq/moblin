import Foundation
import SwiftUI

struct AlertFontView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    @State var fontSize: Float
    @State var fontDesign: SettingsFontDesign
    @State var fontWeight: SettingsFontWeight

    var body: some View {
        if alert.positionType == .scene {
            Section {
                HStack {
                    Text("Size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 80,
                        step: 5,
                        label: {
                            EmptyView()
                        }
                    )
                    .onChange(of: fontSize) { value in
                        alert.fontSize = Int(value)
                        model.updateAlertsSettings()
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 35)
                }
                Picker("Design", selection: $fontDesign) {
                    ForEach(SettingsFontDesign.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: fontDesign) {
                    alert.fontDesign = $0
                    model.updateAlertsSettings()
                }
                Picker("Weight", selection: $fontWeight) {
                    ForEach(SettingsFontWeight.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
                .onChange(of: fontWeight) {
                    alert.fontWeight = $0
                    model.updateAlertsSettings()
                }
            } header: {
                Text("Font")
            }
        }
    }
}

struct AlertColorsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    @State var textColor: Color
    @State var accentColor: Color

    var body: some View {
        if alert.positionType == .scene {
            Section {
                RgbColorPickerView(title: "Text", color: $textColor) {
                    alert.textColor = $0
                    model.updateAlertsSettings()
                }
                RgbColorPickerView(title: "Accent", color: $accentColor) {
                    alert.accentColor = $0
                    model.updateAlertsSettings()
                }
            } header: {
                Text("Colors")
            }
        }
    }
}
