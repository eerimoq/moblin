import SwiftUI

struct ScoreboardColorsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard

    private func updateEffect() {
        model.updateScoreboardEffect(widget: widget)
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

struct WidgetScoreboardSettingsView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var scoreboard: SettingsWidgetScoreboard
    @ObservedObject var web: SettingsRemoteControlWeb

    var body: some View {
        Section {
            Picker("Sport", selection: $scoreboard.sport) {
                ForEach(SettingsWidgetScoreboardSport.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: scoreboard.sport) { _ in
                scoreboard.modular.config = nil
                model.remoteControlScoreboardUpdate()
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            switch scoreboard.sport {
            case .padel:
                WidgetScoreboardPadelGeneralSettingsView(model: model,
                                                         widget: widget,
                                                         scoreboard: scoreboard,
                                                         padel: scoreboard.padel)
            case .generic:
                WidgetScoreboardGenericGeneralSettingsView(model: model,
                                                           widget: widget,
                                                           scoreboard: scoreboard,
                                                           generic: scoreboard.generic)
            default:
                WidgetScoreboardModularGeneralSettingsView(model: model,
                                                           widget: widget,
                                                           modular: scoreboard.modular)
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
            WidgetScoreboardPadelSettingsView(model: model, padel: scoreboard.padel)
        case .generic:
            WidgetScoreboardGenericSettingsView(model: model,
                                                generic: scoreboard.generic,
                                                clock: scoreboard.generic.clock)
        default:
            WidgetScoreboardModularSettingsView(model: model,
                                                widget: widget,
                                                modular: scoreboard.modular,
                                                clock: scoreboard.modular.clock)
        }
    }
}
