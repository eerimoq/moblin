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
                return .white
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
                    text: model.srtlaConnectionStatistics,
                    textFirst: true,
                    color: netStreamColor()
                )
            }
            Spacer()
            if database.show.zoom! {
                if model.cameraPosition == .front {
                    Picker("", selection: $model.frontZoomId) {
                        ForEach(model.zoomLevels) { level in
                            Text(level.name).tag(level.id)
                        }
                    }
                    .onChange(of: model.frontZoomId) { id in
                        model.setCameraZoomLevel(id: id)
                    }
                    .pickerStyle(.segmented)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                    .frame(width: CGFloat(50 * model.zoomLevels.count))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.secondary)
                    )
                    .padding([.bottom], 5)
                } else {
                    Picker("", selection: $model.backZoomId) {
                        ForEach(model.zoomLevels) { level in
                            Text(level.name).tag(level.id)
                        }
                    }
                    .onChange(of: model.backZoomId) { id in
                        model.setCameraZoomLevel(id: id)
                    }
                    .pickerStyle(.segmented)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                    .frame(width: CGFloat(50 * model.zoomLevels.count))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.secondary)
                    )
                    .padding([.bottom], 5)
                }
            }
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
            .background(Color(uiColor: .systemBackground).opacity(0.8))
            .frame(width: CGFloat(70 * model.enabledScenes.count))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.secondary)
            )
        }
    }
}
