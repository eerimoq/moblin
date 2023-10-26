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
    @EnvironmentObject var model: Model
    var color: RgbColor
    @State var red: Float
    @State var green: Float
    @State var blue: Float
    let onChange: () -> Void

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
    @EnvironmentObject var model: Model
    @State var showUsernameColor: Bool = false
    @State var showMessageColor: Bool = false
    @State var showBackgroundColor: Bool = false
    @State var showShadowColor: Bool = false
    @State var usernameColor: Color
    @State var messageColor: Color
    @State var backgroundColor: Color
    @State var shadowColor: Color

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
                    ColorEditView(color: model.database.chat!.usernameColor,
                                  red: Float(model.database.chat!
                                      .usernameColor.red),
                                  green: Float(model.database
                                      .chat!.usernameColor.green),
                                  blue: Float(model.database.chat!
                                      .usernameColor.blue))
                    {
                        usernameColor = model.database.chat!.usernameColor.color()
                    }
                }
                Button {
                    showMessageColor.toggle()
                } label: {
                    HStack {
                        Text("Message")
                        Spacer()
                        ColorCircle(color: messageColor)
                    }
                }
                .foregroundColor(.primary)
                if showMessageColor {
                    ColorEditView(color: model.database.chat!.messageColor,
                                  red: Float(model.database.chat!
                                      .messageColor.red),
                                  green: Float(model.database
                                      .chat!.messageColor.green),
                                  blue: Float(model.database.chat!
                                      .messageColor.blue))
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
                            ColorCircle(color: backgroundColor)
                        }
                    }
                }
                .foregroundColor(.primary)
                if showBackgroundColor {
                    ColorEditView(color: model.database.chat!.backgroundColor,
                                  red: Float(model.database.chat!
                                      .backgroundColor.red),
                                  green: Float(model.database
                                      .chat!.backgroundColor.green),
                                  blue: Float(model.database.chat!
                                      .backgroundColor.blue))
                    {
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
                            ColorCircle(color: shadowColor)
                        }
                    }
                }
                .foregroundColor(.primary)
                if showShadowColor {
                    ColorEditView(color: model.database.chat!.shadowColor,
                                  red: Float(model.database.chat!
                                      .shadowColor.red),
                                  green: Float(model.database
                                      .chat!.shadowColor.green),
                                  blue: Float(model.database.chat!
                                      .shadowColor.blue))
                    {
                        shadowColor = model.database.chat!.shadowColor.color()
                    }
                }
            }
        }
        .navigationTitle("Chat")
    }
}
