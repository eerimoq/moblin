import SwiftUI

struct WidgetScoreboardQuickButtonControlsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    var body: some View {
        switch scoreboard.sport {
        case .generic:
            WidgetScoreboardGenericQuickButtonControlsView(model: model, widget: widget)
        case .padel:
            WidgetScoreboardPadelQuickButtonControlsView(model: model, widget: widget)
        default:
            EmptyView()
        }
    }
}

struct ScoreboardColorsView: View {
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    let updated: () -> Void

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    ColorPicker("Text", selection: $scoreboard.textColorColor, supportsOpacity: false)
                        .onChange(of: scoreboard.textColorColor) { _ in
                            if let color = scoreboard.textColorColor.toRgb() {
                                scoreboard.textColor = color
                            }
                            updated()
                        }
                    ColorPicker("Primary background",
                                selection: $scoreboard.primaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.primaryBackgroundColorColor) { _ in
                            if let color = scoreboard.primaryBackgroundColorColor.toRgb() {
                                scoreboard.primaryBackgroundColor = color
                            }
                            updated()
                        }
                    ColorPicker("Secondary background",
                                selection: $scoreboard.secondaryBackgroundColorColor,
                                supportsOpacity: false)
                        .onChange(of: scoreboard.secondaryBackgroundColorColor) { _ in
                            if let color = scoreboard.secondaryBackgroundColorColor.toRgb() {
                                scoreboard.secondaryBackgroundColor = color
                            }
                            updated()
                        }
                }
                Section {
                    TextButtonView("Reset") {
                        scoreboard.resetColors()
                        updated()
                    }
                }
            }
            .navigationTitle("Colors")
        } label: {
            Text("Colors")
        }
    }
}

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    @ObservedObject var web: SettingsRemoteControlWeb

    private func updated() {
        switch scoreboard.sport {
        case .generic:
            model.sendUpdateGenericScoreboardToWatch(id: widget.id, generic: scoreboard.generic)
        case .padel:
            model.sendUpdatePadelScoreboardToWatch(id: widget.id, padel: scoreboard.padel)
        default:
            break
        }
        model.remoteControlScoreboardUpdate(scoreboard: scoreboard)
        model.getScoreboardEffect(id: widget.id)?
            .update(
                scoreboard: scoreboard,
                config: model.getModularScoreboardConfig(scoreboard: scoreboard),
                players: model.database.scoreboardPlayers
            )
    }

    var body: some View {
        Section {
            Picker("Sport", selection: $scoreboard.sport) {
                ForEach(SettingsWidgetScoreboardSport.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: scoreboard.sport) { _ in
                scoreboard.modular.config = nil
                updated()
            }
            switch scoreboard.sport {
            case .padel:
                WidgetScoreboardPadelGeneralSettingsView(widget: widget,
                                                         scoreboard: scoreboard,
                                                         padel: scoreboard.padel,
                                                         updated: updated)
            case .generic:
                WidgetScoreboardGenericGeneralSettingsView(widget: widget,
                                                           scoreboard: scoreboard,
                                                           generic: scoreboard.generic,
                                                           updated: updated)
            default:
                WidgetScoreboardModularGeneralSettingsView(modular: scoreboard.modular,
                                                           updated: updated)
            }
        }
        Section {
            switch scoreboard.sport {
            case .padel, .generic:
                Text("Use your Apple Watch to update the scoreboard.")
            default:
                Text("Use the web based remote control on another device to update the scoreboard.")
                if web.enabled {
                    RemoteControlWebDefaultUrlView(web: web,
                                                   status: model.statusOther,
                                                   path: "/remote.html")
                }
                RemoteControlWebShortcutView(model: model)
                if !web.enabled {
                    Text("⚠️ The web based remote control is not enabled.")
                }
            }
        } header: {
            Text("Remote control")
        }
        switch scoreboard.sport {
        case .padel:
            WidgetScoreboardPadelSettingsView(model: model, padel: scoreboard.padel, updated: updated)
        case .generic:
            WidgetScoreboardGenericSettingsView(generic: scoreboard.generic,
                                                clock: scoreboard.generic.clock,
                                                updated: updated)
        default:
            WidgetScoreboardModularSettingsView(modular: scoreboard.modular,
                                                clock: scoreboard.modular.clock,
                                                updated: updated)
        }
    }
}
