import SwiftUI

private let barsPerDb: Float = 0.3
private let redThresholdDb: Float = -8.5
private let yellowThresholdDb: Float = -20
private let zeroThresholdDb: Float = -60

struct AudioLevelView: View {
    var showBar: Bool
    var level: Float

    private func bars(count: Float) -> String {
        var bar = ""
        for _ in stride(from: 0, to: count.rounded(.toNearestOrAwayFromZero), by: 1) {
            bar.append("|")
        }
        return bar
    }

    private func redText() -> String {
        guard level > redThresholdDb else {
            return ""
        }
        let db = level - redThresholdDb
        return bars(count: db * barsPerDb)
    }

    private func yellowText() -> String {
        guard level > yellowThresholdDb else {
            return ""
        }
        let db = min(level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return bars(count: db * barsPerDb)
    }

    private func greenText() -> String {
        guard level > zeroThresholdDb else {
            return ""
        }
        let db = min(level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return bars(count: db * barsPerDb)
    }

    var body: some View {
        HStack(spacing: 1) {
            if !level.isNaN {
                if showBar {
                    HStack(spacing: 0) {
                        Text(redText())
                            .foregroundColor(.red)
                        Text(yellowText())
                            .foregroundColor(.yellow)
                        Text(greenText())
                            .foregroundColor(.green)
                    }
                    .padding([.leading, .trailing], 2)
                    .padding([.bottom], 2)
                    .background(Color(white: 0, opacity: 0.6))
                    .cornerRadius(5)
                    .font(.system(size: 13))
                    .bold()
                } else {
                    Text("\(Int(level)) dB")
                        .padding([.leading, .trailing], 2)
                        .background(Color(white: 0, opacity: 0.6))
                        .cornerRadius(5)
                        .font(.system(size: 13))
                }
            } else {
                Text("Muted")
                    .padding([.leading, .trailing], 2)
                    .foregroundColor(.white)
                    .background(Color(white: 0, opacity: 0.6))
                    .cornerRadius(5)
                    .font(.system(size: 13))
            }
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(.system(size: 13))
                .padding([.leading, .trailing], 2)
                .padding([.bottom], showBar ? 2 : 0)
                .foregroundColor(.white)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(5)
        }
        .padding(0)
    }
}

struct RightOverlayView: View {
    @ObservedObject var model: Model

    private var database: Database {
        model.settings.database
    }

    private func netStreamColor() -> Color {
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
                AudioLevelView(showBar: database.show.audioBar!, level: model.audioLevel)
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
            if database.show.zoomPresets! {
                if model.cameraPosition == .front {
                    Picker("", selection: $model.frontZoomPresetId) {
                        ForEach(database.zoom!.front) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .onChange(of: model.frontZoomPresetId) { id in
                        model.setCameraZoomPreset(id: id)
                    }
                    .pickerStyle(.segmented)
                    .padding([.bottom], 1)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                    .frame(width: CGFloat(50 * database.zoom!.front.count))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.secondary)
                    )
                    .padding([.bottom], 5)
                } else {
                    Picker("", selection: $model.backZoomPresetId) {
                        ForEach(database.zoom!.back) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .onChange(of: model.backZoomPresetId) { id in
                        model.setCameraZoomPreset(id: id)
                    }
                    .pickerStyle(.segmented)
                    .padding([.bottom], 1)
                    .background(Color(uiColor: .systemBackground).opacity(0.8))
                    .frame(width: CGFloat(50 * database.zoom!.back.count))
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
            .padding([.bottom], 1)
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
