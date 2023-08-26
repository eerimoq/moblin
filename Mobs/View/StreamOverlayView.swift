import Combine
import Foundation
import SwiftUI

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
                HStack {
                    Image(systemName: "person.2.fill")
                    TextView(text: model.viewers)
                }
            }
            if model.settings.database.uptime {
                HStack {
                    Image(systemName: "deskclock.fill")
                    TextView(text: "0:35:12")
                }
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
            Picker("Selected scene", selection: Binding(get: {
                model.selectedScene
            }, set: { (scene) in
                print("Selected scene:", scene)
                model.selectedScene = scene
            })) {
                ForEach(model.scenes, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: CGFloat(50 * model.scenes.count))
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
