import SwiftUI

private struct ColorsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?
            .update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    ColorPicker("Text", selection: $scoreboard.textColorColor, supportsOpacity: false)
                        .onChange(of: scoreboard.textColorColor) { _ in
                            if let color = scoreboard.textColorColor.toRgb() {
                                scoreboard.textColor = color
                            }
                            updateEffect()
                        }
                    ColorPicker("Primary background",
                                selection: $scoreboard.primaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.primaryBackgroundColorColor) { _ in
                            if let color = scoreboard.primaryBackgroundColorColor.toRgb() {
                                scoreboard.primaryBackgroundColor = color
                            }
                            updateEffect()
                        }
                    ColorPicker("Secondary background",
                                selection: $scoreboard.secondaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.secondaryBackgroundColorColor) { _ in
                            if let color = scoreboard.secondaryBackgroundColorColor.toRgb() {
                                scoreboard.secondaryBackgroundColor = color
                            }
                            updateEffect()
                        }
                }
                Section {
                    TextButtonView("Reset") {
                        scoreboard.resetColors()
                        updateEffect()
                    }
                }
            }
            .navigationTitle("Colors")
        } label: {
            Text("Colors")
        }
    }
}

private struct StackedSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    HStack {
                        Text("Font size")
                        Slider(value: $scoreboard.stackedFontSize, in: 5...50)
                            .onChange(of: scoreboard.stackedFontSize) { _ in updateEffect() }
                        Text("\(Int(scoreboard.stackedFontSize))").frame(width: 30)
                    }
                    HStack {
                        Text("Total width")
                        Slider(value: $scoreboard.stackedWidth, in: 200...500)
                            .onChange(of: scoreboard.stackedWidth) { _ in updateEffect() }
                        Text("\(Int(scoreboard.stackedWidth))").frame(width: 30)
                    }
                    HStack {
                        Text("Row height")
                        Slider(value: $scoreboard.stackedRowHeight, in: 10...60)
                            .onChange(of: scoreboard.stackedRowHeight) { _ in updateEffect() }
                        Text("\(Int(scoreboard.stackedRowHeight))").frame(width: 30)
                    }
                } header: { Text("Dimensions") }

                Section {
                    Toggle("Bold", isOn: $scoreboard.stackedIsBold)
                        .onChange(of: scoreboard.stackedIsBold) { _ in updateEffect() }
                    Toggle("Italic", isOn: $scoreboard.stackedIsItalic)
                        .onChange(of: scoreboard.stackedIsItalic) { _ in updateEffect() }
                    Toggle("Show title & time", isOn: $scoreboard.showStackedHeader)
                        .onChange(of: scoreboard.showStackedHeader) { _ in updateEffect() }
                    Toggle("Show Moblin footer", isOn: $scoreboard.showStackedFooter)
                        .onChange(of: scoreboard.showStackedFooter) { _ in updateEffect() }
                } header: { Text("Style") }
            }
            .navigationTitle("Stacked layout")
        } label: {
            Text("Stacked layout settings")
        }
    }
}

private struct SideBySideSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    HStack {
                        Text("Font size")
                        Slider(value: $scoreboard.sbsFontSize, in: 5...50)
                            .onChange(of: scoreboard.sbsFontSize) { _ in updateEffect() }
                        Text("\(Int(scoreboard.sbsFontSize))").frame(width: 30)
                    }
                    HStack {
                        Text("Total width")
                        Slider(value: $scoreboard.sbsWidth, in: 200...700)
                            .onChange(of: scoreboard.sbsWidth) { _ in updateEffect() }
                        Text("\(Int(scoreboard.sbsWidth))").frame(width: 30)
                    }
                    HStack {
                        Text("Row height")
                        Slider(value: $scoreboard.sbsRowHeight, in: 10...60)
                            .onChange(of: scoreboard.sbsRowHeight) { _ in updateEffect() }
                        Text("\(Int(scoreboard.sbsRowHeight))").frame(width: 30)
                    }
                } header: { Text("Dimensions") }

                Section {
                    Toggle("Bold", isOn: $scoreboard.sbsIsBold)
                        .onChange(of: scoreboard.sbsIsBold) { _ in updateEffect() }
                    Toggle("Italic", isOn: $scoreboard.sbsIsItalic)
                        .onChange(of: scoreboard.sbsIsItalic) { _ in updateEffect() }
                    Toggle("Show title", isOn: $scoreboard.showSbsTitle)
                        .onChange(of: scoreboard.showSbsTitle) { _ in updateEffect() }
                } header: { Text("Style") }
            }
            .navigationTitle("Side by side layout")
        } label: {
            Text("Side by side settings")
        }
    }
}

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    var body: some View {
        Section {
            Picker("Type", selection: $scoreboard.type) {
                ForEach(SettingsWidgetScoreboardType.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: scoreboard.type) { _ in model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            
            Picker("Layout", selection: $scoreboard.layout) {
                ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: scoreboard.layout) { _ in model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard, players: model.database.scoreboardPlayers)
            }

            if scoreboard.layout == .stacked {
                StackedSettingsView(model: model, widget: widget, scoreboard: scoreboard)
            } else if scoreboard.layout == .sideBySide {
                SideBySideSettingsView(model: model, widget: widget, scoreboard: scoreboard)
            }
            
            switch scoreboard.type {
            case .padel:
                WidgetScoreboardPadelGeneralSettingsView(model: model, padel: scoreboard.padel)
            case .generic:
                WidgetScoreboardGenericGeneralSettingsView(model: model, generic: scoreboard.generic)
            }
            ColorsView(model: model, widget: widget, scoreboard: scoreboard)
        } header: {
            Text("General")
        }
        switch scoreboard.type {
        case .padel:
            WidgetScoreboardPadelSettingsView(model: model, padel: scoreboard.padel)
        case .generic:
            WidgetScoreboardGenericSettingsView(model: model, generic: scoreboard.generic)
        }
    }
}
