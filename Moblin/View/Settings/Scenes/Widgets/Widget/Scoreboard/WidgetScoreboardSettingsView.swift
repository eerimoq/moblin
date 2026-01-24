import SwiftUI

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    var body: some View {
        Section {
            Picker("Sport", selection: $scoreboard.sportId) {
                ForEach(model.getAvailableSports(), id: \.self) { (sport: String) in
                    Text(sport.capitalized).tag(sport)
                }
            }
            .onChange(of: scoreboard.sportId) { _ in
                scoreboard.config = nil
                model.externalScoreboard = nil
                model.broadcastCurrentState()
                model.sceneUpdated()
            }

            Picker("Layout", selection: $scoreboard.layout) {
                ForEach(SettingsWidgetScoreboardLayout.allCases, id: \.self) { layout in
                    Text(layout.rawValue).tag(layout)
                }
            }
            .onChange(of: scoreboard.layout) { _ in
                model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard)
                model.broadcastCurrentState()
            }

            if scoreboard.layout == .stacked || scoreboard.layout == .stackhistory || scoreboard
                .layout == .stackedInline
            {
                StackedSettingsView(model: model, widget: widget, scoreboard: scoreboard)
            } else if scoreboard.layout == .sideBySide {
                SideBySideSettingsView(model: model, widget: widget, scoreboard: scoreboard)
            }

            HStack {
                Text("Timer duration (min)").layoutPriority(1)
                Spacer()
                TextField("", value: $scoreboard.generic.clockMaximum, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            Picker("Timer direction", selection: $scoreboard.generic.clockDirection) {
                ForEach(SettingsWidgetGenericScoreboardClockDirection.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
        } header: { Text("General") }

        Section {
            TextEditNavigationView(title: "Team 1 Name", value: scoreboard.generic.home) {
                scoreboard.generic.home = $0
                model.broadcastCurrentState()
                model.sceneUpdated()
            }
            TextEditNavigationView(title: "Team 2 Name", value: scoreboard.generic.away) {
                scoreboard.generic.away = $0
                model.broadcastCurrentState()
                model.sceneUpdated()
            }
            ColorsView(model: model, widget: widget, scoreboard: scoreboard)
        } header: { Text("Teams") }
    }
}

private struct ColorsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard)
    }

    var body: some View {
        NavigationLink("Team Colors") {
            Form {
                Section {
                    ColorPicker(
                        "Text Color",
                        selection: $scoreboard.team1TextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: scoreboard.team1TextColorColor) {
                        if let rgb = $0.toRgb() { scoreboard.team1TextColor = rgb }; model
                            .broadcastCurrentState(); updateEffect()
                    }
                    ColorPicker(
                        "Background Color",
                        selection: $scoreboard.team1BgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: scoreboard.team1BgColorColor) {
                        if let rgb = $0.toRgb() { scoreboard.team1BgColor = rgb }; model
                            .broadcastCurrentState(); updateEffect()
                    }
                } header: { Text("Team 1") }
                Section {
                    ColorPicker(
                        "Text Color",
                        selection: $scoreboard.team2TextColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: scoreboard.team2TextColorColor) {
                        if let rgb = $0.toRgb() { scoreboard.team2TextColor = rgb }; model
                            .broadcastCurrentState(); updateEffect()
                    }
                    ColorPicker(
                        "Background Color",
                        selection: $scoreboard.team2BgColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: scoreboard.team2BgColorColor) {
                        if let rgb = $0.toRgb() { scoreboard.team2BgColor = rgb }; model
                            .broadcastCurrentState(); updateEffect()
                    }
                } header: { Text("Team 2") }
                Section {
                    ColorPicker(
                        "Main Background",
                        selection: $scoreboard.secondaryBackgroundColorColor,
                        supportsOpacity: false
                    )
                    .onChange(of: scoreboard.secondaryBackgroundColorColor) {
                        if let rgb = $0.toRgb() { scoreboard.secondaryBackgroundColor = rgb }; updateEffect()
                    }
                    Button("Reset All Colors") {
                        scoreboard.resetColors(); model.broadcastCurrentState(); updateEffect()
                    }
                } header: { Text("Global Style") }
            }.navigationTitle("Colors")
        }
    }
}

private struct StackedSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard)
    }

    var body: some View {
        NavigationLink("Stacked Layout Settings") {
            Form {
                Section {
                    HStack { Text("Font size").layoutPriority(1); Slider(
                        value: $scoreboard.stackedFontSize,
                        in: 5 ... 25
                    )
                    .onChange(of: scoreboard.stackedFontSize) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.stackedFontSize))").frame(width: 35)
                    }
                    HStack { Text("Total width").layoutPriority(1); Slider(
                        value: $scoreboard.stackedWidth,
                        in: 150 ... 650
                    )
                    .onChange(of: scoreboard.stackedWidth) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.stackedWidth))").frame(width: 35)
                    }
                    HStack { Text("Row height").layoutPriority(1); Slider(
                        value: $scoreboard.stackedRowHeight,
                        in: 10 ... 35
                    )
                    .onChange(of: scoreboard.stackedRowHeight) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.stackedRowHeight))").frame(width: 35)
                    }
                } header: { Text("Dimensions") }
                Section {
                    Toggle("Bold", isOn: $scoreboard.stackedIsBold)
                        .onChange(of: scoreboard.stackedIsBold) { _ in updateEffect() }
                    Toggle("Italic", isOn: $scoreboard.stackedIsItalic)
                        .onChange(of: scoreboard.stackedIsItalic) { _ in updateEffect() }
                    Toggle("Show Title", isOn: $scoreboard.showStackedHeader)
                        .onChange(of: scoreboard.showStackedHeader) { _ in updateEffect() }
                    if scoreboard
                        .showStackedHeader
                    {
                        Toggle("Title on Top", isOn: $scoreboard.titleAbove)
                            .onChange(of: scoreboard.titleAbove) { _ in updateEffect() }
                    }
                    Toggle("Show Moblin footer", isOn: $scoreboard.showStackedFooter)
                        .onChange(of: scoreboard.showStackedFooter) { _ in updateEffect() }
                } header: { Text("Basic Style") }
                Section {
                    Toggle("Second Row (TO, Foul, etc.)", isOn: $scoreboard.showSecondaryRows)
                        .onChange(of: scoreboard.showSecondaryRows) { _ in updateEffect() }
                    Toggle("Info Box (Time, Period)", isOn: $scoreboard.showGlobalStatsBlock)
                        .onChange(of: scoreboard.showGlobalStatsBlock) { _ in updateEffect() }
                } header: { Text("Modular Layout") }
            }.navigationTitle("Stacked Layout")
        }
    }
}

private struct SideBySideSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.getScoreboardEffect(id: widget.id)?.update(scoreboard: scoreboard)
    }

    var body: some View {
        NavigationLink("Side by Side Settings") {
            Form {
                Section {
                    HStack { Text("Font size").layoutPriority(1); Slider(
                        value: $scoreboard.sbsFontSize,
                        in: 5 ... 25
                    )
                    .onChange(of: scoreboard.sbsFontSize) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.sbsFontSize))").frame(width: 35)
                    }
                    HStack { Text("Total width").layoutPriority(1); Slider(
                        value: $scoreboard.sbsWidth,
                        in: 150 ... 650
                    )
                    .onChange(of: scoreboard.sbsWidth) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.sbsWidth))").frame(width: 35)
                    }
                    HStack { Text("Row height").layoutPriority(1); Slider(
                        value: $scoreboard.sbsRowHeight,
                        in: 10 ... 35
                    )
                    .onChange(of: scoreboard.sbsRowHeight) { _ in
                        updateEffect()
                    }; Text("\(Int(scoreboard.sbsRowHeight))").frame(width: 35)
                    }
                } header: { Text("Dimensions") }
                Section {
                    Toggle("Bold", isOn: $scoreboard.sbsIsBold)
                        .onChange(of: scoreboard.sbsIsBold) { _ in updateEffect() }
                    Toggle("Italic", isOn: $scoreboard.sbsIsItalic)
                        .onChange(of: scoreboard.sbsIsItalic) { _ in updateEffect() }
                    Toggle("Show Title", isOn: $scoreboard.showSbsTitle)
                        .onChange(of: scoreboard.showSbsTitle) { _ in updateEffect() }
                } header: { Text("Basic Style") }
                Section {
                    Toggle("Second Row (TO, Foul, etc.)", isOn: $scoreboard.showSecondaryRows)
                        .onChange(of: scoreboard.showSecondaryRows) { _ in updateEffect() }
                    Toggle("Info Box (Time, Period)", isOn: $scoreboard.showGlobalStatsBlock)
                        .onChange(of: scoreboard.showGlobalStatsBlock) { _ in updateEffect() }
                } header: { Text("Modular Layout") }
            }.navigationTitle("Side by Side")
        }
    }
}
