import AVFoundation
import SwiftUI

private struct WidgetView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var sceneWidget: SettingsSceneWidget

    var body: some View {
        NavigationLink {
            SceneWidgetSettingsView(
                model: model,
                database: database,
                sceneWidget: sceneWidget,
                widget: widget
            )
        } label: {
            Toggle(isOn: $widget.enabled) {
                IconAndTextView(
                    image: widget.image(),
                    text: widget.name,
                    longDivider: true
                )
            }
            .onChange(of: widget.enabled) { _ in
                model.reloadSpeechToText()
                model.sceneUpdated(attachCamera: model.isCaptureDeviceWidget(widget: widget))
            }
        }
        switch widget.type {
        case .text:
            WidgetTextQuickButtonControlsView(model: model,
                                              widget: widget,
                                              text: widget.text)
        case .wheelOfLuck:
            WidgetWheelOfLuckQuickButtonControlsView(model: model, widget: widget)
        case .bingoCard:
            WidgetBingoCardQuickButtonControlsView(bingoCard: widget.bingoCard) {
                model.getBingoCardEffect(id: widget.id)?.setSettings(settings: widget.bingoCard)
            }
        case .scoreboard:
            WidgetScoreboardQuickButtonControlsView(model: model,
                                                    widget: widget,
                                                    scoreboard: widget.scoreboard)
        default:
            EmptyView()
        }
    }
}

struct QuickButtonSceneWidgetsView: View {
    @EnvironmentObject var model: Model
    // periphery:ignore
    @ObservedObject var sceneSelector: SceneSelector

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.widgetsInCurrentScene(onlyEnabled: false)) { widget in
                        WidgetView(model: model,
                                   database: model.database,
                                   widget: widget.widget,
                                   sceneWidget: widget.sceneWidget)
                    }
                }
            }
            ShortcutSectionView {
                ScenesShortcutView(database: model.database)
            }
        }
        .navigationTitle("Scene widgets")
    }
}
