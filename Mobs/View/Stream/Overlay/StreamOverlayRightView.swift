import SwiftUI

struct AudioLevelView: View {
    var showBar: Bool
    var level: Float

    private func text() -> String {
        if level.isNaN {
            return "Muted"
        } else if !showBar {
            return "\(Int(level)) dB"
        } else {
            let level = (max(level, -60) + 60) / 60
            let numberOfBars = min(Int(level * 19) + 1, 19)
            var bar = ""
            for _ in stride(from: 0, to: numberOfBars, by: 1) {
                bar.append("|")
            }
            return bar
        }
    }
    
    private func color() -> Color {
         if level > -8 {
            return .red
        } else if level > -18 {
            return .yellow
        } else {
            return .white
        }
    }
    
    var body: some View {
        HStack(spacing: 1) {
            Text(text())
                .foregroundColor(.white)
                .padding([.leading, .trailing], 2)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(5)
                .font(.system(size: 13))
            Image(systemName: "waveform")
                .frame(width: 17, height: 17)
                .font(.system(size: 13))
                .padding([.leading, .trailing], 2)
                .foregroundColor(color())
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
