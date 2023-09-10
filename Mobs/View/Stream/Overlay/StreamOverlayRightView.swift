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
        get {
            model.settings.database
        }
    }

    var body: some View {
        VStack(alignment: .trailing) {
            if database.show.speed {
                StreamOverlayIconAndTextView(icon: "speedometer", text: model.speed, textFirst: true)
            }
            if database.show.fps {
                StreamOverlayIconAndTextView(icon: "film.stack", text: model.fps, textFirst: true)
            }
            Spacer()
            Picker("", selection: $model.sceneIndex) {
                ForEach(0..<model.enabledScenes.count, id: \.self) { id in
                    let scene = model.enabledScenes[id]
                    Text(scene.name).tag(scene.id)
                }
            }
            .onChange(of: model.sceneIndex) { tag in
                model.selectedSceneId = model.enabledScenes[tag].id
                model.sceneUpdated()
            }
            .pickerStyle(.segmented)
            .colorMultiply(.orange)
            .frame(width: CGFloat(50 * database.scenes.filter({scene in scene.enabled}).count))
            .background(Color(white: 1, opacity: 0.6))
            .colorInvert()
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.secondary)
            )
        }
    }
}
