import SwiftUI

struct TextView: View {
    var text: String

    var body: some View {
        Text(text)
            .foregroundColor(.white)
            .padding([.leading, .trailing], 2)
            .background(Color(white: 0, opacity: 0.6))
            .cornerRadius(5)
    }
}

struct IconAndText: View {
    var icon: String
    var text: String
    var textFirst = false

    var body: some View {
        HStack {
            if textFirst {
                TextView(text: text)
                    .font(.system(size: 13))
            }
            Image(systemName: icon)
                .frame(width: 12)
                .font(.system(size: 13))
            if !textFirst {
                TextView(text: text)
                    .font(.system(size: 13))
            }
        }
        .padding(0)
    }
}

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
                print(value)
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

struct LeadingOverlayView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if database.show.connection {
                IconAndText(icon: "app.connected.to.app.below.fill", text: model.connection?.name ?? "")
            }
            if database.show.viewers {
                IconAndText(icon: "eye", text: model.numberOfViewers)
            }
            if database.show.uptime {
                IconAndText(icon: "deskclock", text: model.uptime)
            }
            Spacer()
            if database.show.chat {
                HStack {
                    Image(systemName: "message")
                        .frame(width: 12)
                    TextView(text: String(format: "%.2f m/s", model.twitchChatPostsPerSecond))
                }
                .font(.system(size: 13))
                .padding([.bottom], 1)
                ChatView(posts: model.twitchChatPosts)
            }
        }
    }
}

struct TrailingOverlayView: View {
    @ObservedObject var model: Model
    
    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        VStack(alignment: .trailing) {
            if database.show.speed {
                IconAndText(icon: "speedometer", text: model.speed, textFirst: true)
            }
            if database.show.resolution {
                IconAndText(icon: "display", text: "1920x1080", textFirst: true)
            }
            if database.show.fps {
                IconAndText(icon: "film.stack", text: model.fps, textFirst: true)
            }
            Spacer()
            // Variable(name: "Earnings", value: "10.32")
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

struct StreamOverlayView: View {
    @ObservedObject var model: Model

    var body: some View {
        HStack {
            LeadingOverlayView(model: model)
            Spacer()
            TrailingOverlayView(model: model)
        }
        .padding([.trailing, .top])
    }
}
