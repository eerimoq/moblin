import AVFoundation
import SwiftUI

private struct WidgetView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
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
        case .pomodoroTimer:
            WidgetPomodoroTimerQuickButtonControlsView(pomodoroTimer: widget.pomodoroTimer)
        default:
            EmptyView()
        }
    }
}

struct QuickButtonSceneWidgetsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var sceneSelector: SceneSelector

    var body: some View {
        let widgets = model.sceneWidgetsInSelectedScene()
        Form {
            Section {
                if widgets.isEmpty {
                    Text("No widgets in this scene")
                } else {
                    List {
                        ForEach(widgets) {
                            WidgetView(model: model, widget: $0.widget)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scene widgets")
    }
}
