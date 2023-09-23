import SwiftUI

struct Variable: View {
    var name: String
    @State var value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(name)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .padding([.top, .trailing, .leading], 5)
            TextField(
                "   ",
                text: $value
            )
            .onSubmit {
                logger.error(value)
            }
            .font(.system(size: 20))
            .fixedSize()
            .padding([.bottom, .trailing, .leading], 5)
        }
        .background(Color(white: 0, opacity: 0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.secondary)
        )
    }
}

struct RightOverlayView: View {
    @ObservedObject var model: Model

    var database: Database {
        model.settings.database
    }

    func netStreamColor() -> Color {
        if model.isStreaming() && !model.isStreamOk() {
            return .red
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
            .frame(width: CGFloat(50 * database.scenes.filter { scene in
                scene.enabled
            }.count))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.secondary)
            )
        }
    }
}
