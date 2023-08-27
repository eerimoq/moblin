import Combine
import Foundation
import SwiftUI

struct IconAndText: View {
    var image: String
    var text: String

    var body: some View {
        HStack {
            Image(systemName: self.image)
                .frame(width: 12, height: 12)
            TextView(text: self.text)
        }
    }
}

struct TextView: View {
    var text: String
    init(text: String) {
        self.text = text
    }

    var body: some View {
        HStack {
            Text(self.text)
                .foregroundColor(.white)
        }.padding(5)
            .background(.black)
            .cornerRadius(10)
    }
}

struct Variable: View {
    var name: String
    @State var value: String

    var body: some View {
        VStack(spacing: 0) {
            Text(self.name)
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
        .background(.black)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.secondary)
        )
    }
}

struct LeadingOverlayView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading) {
            if model.settings.database.viewers {
                IconAndText(image: "person.2.fill", text: model.viewers)
            }
            if model.settings.database.uptime {
                IconAndText(image: "deskclock.fill", text: model.uptime)
            }
            Spacer()
            if model.settings.database.chat {
                TextView(text: model.chatText)
            }
        }
    }
}

struct TrailingOverlayView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .trailing) {
            TextView(text: model.fps)
            Spacer()
            Variable(name: "Earnings", value: "10.32")
            Picker("", selection: Binding(get: {
                model.selectedScene
            }, set: { (scene) in
                model.selectedScene = scene
            })) {
                ForEach(model.settings.database.scenes.filter({scene in scene.enabled}).map({scene in scene.name}), id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: CGFloat(50 * model.settings.database.scenes.filter({scene in scene.enabled}).count))
            .colorInvert()
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
        }.padding([.trailing, .top])
    }
}

struct StreamOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        StreamOverlayView(model: Model())
    }
}
