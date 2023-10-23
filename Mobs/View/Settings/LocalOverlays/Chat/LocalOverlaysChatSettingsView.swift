import SwiftUI

struct ColorCircle: View {
    var color: Color

    var body: some View {
        Circle()
            .frame(width: 30, height: 30)
            .foregroundColor(color)
            .overlay(
                Circle()
                    .stroke(.secondary, lineWidth: 2)
            )
    }
}

struct ColorEditView: View {
    @ObservedObject var model: Model
    var color: RgbColor
    @State var red: Float
    @State var green: Float
    @State var blue: Float
    private let onChange: () -> Void

    init(model: Model, color: RgbColor, onChange: @escaping () -> Void) {
        self.model = model
        self.color = color
        self.onChange = onChange
        red = Float(color.red)
        green = Float(color.green)
        blue = Float(color.blue)
    }

    var body: some View {
        HStack {
            Text("Red")
                .frame(width: 60)
            Slider(
                value: $red,
                in: 0 ... 255,
                step: 1,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    color.red = Int(red)
                    model.store()
                }
            )
            .onChange(of: red) { value in
                color.red = Int(value)
                onChange()
            }
            Text(String(Int(red)))
                .frame(width: 35)
        }
        HStack {
            Text("Green")
                .frame(width: 60)
            Slider(
                value: $green,
                in: 0 ... 255,
                step: 1,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    color.green = Int(green)
                    model.store()
                }
            )
            .onChange(of: green) { value in
                color.green = Int(value)
                onChange()
            }
            Text(String(Int(green)))
                .frame(width: 35)
        }
        HStack {
            Text("Blue")
                .frame(width: 60)
            Slider(
                value: $blue,
                in: 0 ... 255,
                step: 1,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    color.blue = Int(blue)
                    model.store()
                }
            )
            .onChange(of: blue) { value in
                color.blue = Int(value)
                onChange()
            }
            Text(String(Int(blue)))
                .frame(width: 35)
        }
    }
}

struct LocalOverlaysChatSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    @State var showUsernameColor: Bool = false
    @State var showMessageColor: Bool = false
    @State var showBackgroundColor: Bool = false
    @State var showShadowColor: Bool = false
    @State var usernameColor: Color
    @State var messageColor: Color
    @State var backgroundColor: Color
    @State var shadowColor: Color

    init(model: Model, toolbar: Toolbar) {
        self.model = model
        self.toolbar = toolbar
        usernameColor = model.database.chat!.usernameColor.color()
        messageColor = model.database.chat!.messageColor.color()
        backgroundColor = model.database.chat!.backgroundColor.color()
        shadowColor = model.database.chat!.shadowColor.color()
    }

    func submitFontSize(value: String) {
        guard let fontSize = Float(value) else {
            return
        }
        guard fontSize > 0 else {
            return
        }
        model.database.chat!.fontSize = fontSize
        model.store()
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    toolbar: toolbar,
                    title: "Font size",
                    value: String(model.database.chat!.fontSize),
                    onSubmit: submitFontSize
                )) {
                    TextItemView(
                        name: "Font size",
                        value: String(model.database.chat!.fontSize)
                    )
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat!.boldUsername!
                }, set: { value in
                    model.database.chat!.boldUsername = value
                    model.store()
                })) {
                    Text("Bold username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat!.boldMessage!
                }, set: { value in
                    model.database.chat!.boldMessage = value
                    model.store()
                })) {
                    Text("Bold message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat!.animatedEmotes!
                }, set: { value in
                    model.database.chat!.animatedEmotes = value
                    model.store()
                })) {
                    Text("Animated emotes")
                }
            } header: {
                Text("General")
            } footer: {
                Text("Animated emotes are fairly CPU intensive.")
            }
            Section("Colors") {
                Button {
                    showUsernameColor.toggle()
                } label: {
                    HStack {
                        Text("Username")
                        Spacer()
                        ColorCircle(color: usernameColor)
                    }
                }
                .foregroundColor(.primary)
                if showUsernameColor {
                    ColorEditView(
                        model: model,
                        color: model.database.chat!.usernameColor
                    ) {
                        usernameColor = model.database.chat!.usernameColor.color()
                    }
                }
                Button {
                    showMessageColor.toggle()
                } label: {
                    HStack {
                        Text("Message")
                        Spacer()
                        ColorCircle(color: model.database.chat!.messageColor.color())
                    }
                }
                .foregroundColor(.primary)
                if showMessageColor {
                    ColorEditView(model: model,
                                  color: model.database.chat!.messageColor)
                    {
                        messageColor = model.database.chat!.messageColor.color()
                    }
                }
                Button {
                    showBackgroundColor.toggle()
                } label: {
                    Toggle(isOn: Binding(get: {
                        model.database.chat!.backgroundColorEnabled
                    }, set: { value in
                        model.database.chat!.backgroundColorEnabled = value
                        model.store()
                    })) {
                        HStack {
                            Text("Background")
                            Spacer()
                            ColorCircle(color: model.database.chat!.backgroundColor
                                .color())
                        }
                    }
                }
                .foregroundColor(.primary)
                if showBackgroundColor {
                    ColorEditView(
                        model: model,
                        color: model.database.chat!.backgroundColor
                    ) {
                        backgroundColor = model.database.chat!.backgroundColor.color()
                    }
                }
                Button {
                    showShadowColor.toggle()
                } label: {
                    Toggle(isOn: Binding(get: {
                        model.database.chat!.shadowColorEnabled
                    }, set: { value in
                        model.database.chat!.shadowColorEnabled = value
                        model.store()
                    })) {
                        HStack {
                            Text("Shadow")
                            Spacer()
                            ColorCircle(color: model.database.chat!.shadowColor.color())
                        }
                    }
                }
                .foregroundColor(.primary)
                if showShadowColor {
                    ColorEditView(model: model, color: model.database.chat!.shadowColor) {
                        shadowColor = model.database.chat!.shadowColor.color()
                    }
                }
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            toolbar
        }
    }
}
