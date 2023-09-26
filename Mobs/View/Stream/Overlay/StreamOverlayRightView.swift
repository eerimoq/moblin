import SwiftUI

struct RightOverlayView: View {
    @ObservedObject var model: Model

    var database: Database {
        model.settings.database
    }

    func netStreamColor() -> Color {
        if model.isStreaming() {
            switch model.streamState {
            case .connecting:
                return .cyan
            case .connected:
                return .white
            case .disconnected:
                return .red
            }
        } else {
            return .white
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if database.show.audioLevel! {
                StreamOverlayIconAndTextView(
                    icon: "waveform",
                    text: model.audioLevel,
                    textFirst: true,
                    color: .white
                )
            }
            if database.show.speed {
                StreamOverlayIconAndTextView(
                    icon: "speedometer",
                    text: model.speedAndTotal,
                    textFirst: true,
                    color: netStreamColor()
                )
            }
            if database.show.uptime {
                StreamOverlayIconAndTextView(
                    icon: "deskclock",
                    text: model.uptime,
                    textFirst: true,
                    color: netStreamColor()
                )
            }
            if model.stream.isSrtla() {
                StreamOverlayIconAndTextView(
                    icon: "phone.connection",
                    text: model.currentConnectionType,
                    textFirst: true,
                    color: netStreamColor()
                )
            }
            Spacer()
            Picker("", selection: $model.sceneIndex) {
                ForEach(0 ..< model.enabledScenes.count, id: \.self) { id in
                    let scene = model.enabledScenes[id]
                    Text(scene.name).tag(scene.id)
                }
            }
            .onChange(of: model.sceneIndex) { tag in
                model.selectedSceneId = model.enabledScenes[tag].id
                model.sceneUpdated()
            }
            .pickerStyle(.segmented)
            .frame(width: CGFloat(70 * model.enabledScenes.count))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.secondary)
            )
        }
    }
}
