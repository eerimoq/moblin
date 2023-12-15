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
                    model.reloadChatMessages()
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
                    model.reloadChatMessages()
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
                    model.reloadChatMessages()
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
    @State var showTimestampColor: Bool = false
    @State var showUsernameColor: Bool = false
    @State var showMessageColor: Bool = false
    @State var showBackgroundColor: Bool = false
    @State var showShadowColor: Bool = false
    @State var timestampColor: Color
    @State var usernameColor: Color
    @State var messageColor: Color
    @State var backgroundColor: Color
    @State var shadowColor: Color
    @State var height: Double
    @State var width: Double
    @State var fontSize: Float

    func submitMaximumAge(value: String) {
        guard let maximumAge = Int(value) else {
            return
        }
        guard maximumAge > 0 else {
            return
        }
        model.database.chat.maximumAge = maximumAge
        model.store()
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 30,
                        step: 1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.fontSize = fontSize
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: fontSize) { value in
                        model.database.chat.fontSize = value
                        model.reloadChatMessages()
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 25)
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.timestampColorEnabled
                }, set: { value in
                    model.database.chat.timestampColorEnabled = value
                    model.store()
                    model.reloadChatMessages()
                })) {
                    Text("Timestamp")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.boldUsername
                }, set: { value in
                    model.database.chat.boldUsername = value
                    model.store()
                    model.reloadChatMessages()
                })) {
                    Text("Bold username")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.boldMessage
                }, set: { value in
                    model.database.chat.boldMessage = value
                    model.store()
                    model.reloadChatMessages()
                })) {
                    Text("Bold message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.animatedEmotes
                }, set: { value in
                    model.database.chat.animatedEmotes = value
                    model.store()
                    model.reloadChatMessages()
                })) {
                    Text("Animated emotes")
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Maximum age"),
                    value: String(model.database.chat.maximumAge!),
                    onSubmit: submitMaximumAge,
                    footer: Text("Maximum message age in seconds.")
                )) {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.maximumAgeEnabled!
                    }, set: { value in
                        model.database.chat.maximumAgeEnabled = value
                        model.store()
                    })) {
                        TextItemView(
                            name: String(localized: "Maximum age"),
                            value: String(model.database.chat.maximumAge!)
                        )
                    }
                }
            } header: {
                Text("General")
            } footer: {
                Text(
                    "Animated emotes are fairly CPU intensive. Disable for less power usage."
                )
            }
            Section("Geometry") {
                HStack {
                    Text("Height")
                    Slider(
                        value: $height,
                        in: 0.2 ... 1.0,
                        step: 0.05,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.height = height
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: height) { value in
                        model.database.chat.height = value
                    }
                    Text("\(Int(100 * height)) %")
                        .frame(width: 55)
                }
                HStack {
                    Text("Width")
                    Slider(
                        value: $width,
                        in: 0.2 ... 1.0,
                        step: 0.05,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.chat.width = width
                            model.store()
                            model.reloadChatMessages()
                        }
                    )
                    .onChange(of: width) { value in
                        model.database.chat.width = value
                    }
                    Text("\(Int(100 * width)) %")
                        .frame(width: 55)
                }
            }
            Section {
                Button {
                    showTimestampColor.toggle()
                } label: {
                    HStack {
                        Text("Timestamp")
                        Spacer()
                        ColorCircle(color: timestampColor)
                    }
                }
                .foregroundColor(.primary)
                if showTimestampColor {
                    ColorEditView(color: model.database.chat.timestampColor,
                                  red: Float(model.database.chat.timestampColor.red),
                                  green: Float(model.database.chat.timestampColor.green),
                                  blue: Float(model.database.chat.timestampColor.blue))
                    {
                        timestampColor = model.database.chat.timestampColor.color()
                    }
                }
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
                    ColorEditView(color: model.database.chat.usernameColor,
                                  red: Float(model.database.chat
                                      .usernameColor.red),
                                  green: Float(model.database
                                      .chat.usernameColor.green),
                                  blue: Float(model.database.chat
                                      .usernameColor.blue))
                    {
                        usernameColor = model.database.chat.usernameColor.color()
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
                    ColorEditView(color: model.database.chat.messageColor,
                                  red: Float(model.database.chat
                                      .messageColor.red),
                                  green: Float(model.database
                                      .chat.messageColor.green),
                                  blue: Float(model.database.chat
                                      .messageColor.blue))
                    {
                        messageColor = model.database.chat.messageColor.color()
                    }
                }
                Button {
                    showBackgroundColor.toggle()
                } label: {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.backgroundColorEnabled
                    }, set: { value in
                        model.database.chat.backgroundColorEnabled = value
                        model.store()
                        model.reloadChatMessages()
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
                    ColorEditView(color: model.database.chat.backgroundColor,
                                  red: Float(model.database.chat
                                      .backgroundColor.red),
                                  green: Float(model.database
                                      .chat.backgroundColor.green),
                                  blue: Float(model.database.chat
                                      .backgroundColor.blue))
                    {
                        backgroundColor = model.database.chat.backgroundColor.color()
                    }
                }
                Button {
                    showShadowColor.toggle()
                } label: {
                    Toggle(isOn: Binding(get: {
                        model.database.chat.shadowColorEnabled
                    }, set: { value in
                        model.database.chat.shadowColorEnabled = value
                        model.store()
                        model.reloadChatMessages()
                    })) {
                        HStack {
                            Text("Border")
                            Spacer()
                            ColorCircle(color: shadowColor)
                        }
                    }
                }
                .foregroundColor(.primary)
                if showShadowColor {
                    ColorEditView(color: model.database.chat.shadowColor,
                                  red: Float(model.database.chat
                                      .shadowColor.red),
                                  green: Float(model.database
                                      .chat.shadowColor.green),
                                  blue: Float(model.database.chat
                                      .shadowColor.blue))
                    {
                        shadowColor = model.database.chat.shadowColor.color()
                    }
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.meInUsernameColor!
                }, set: { value in
                    model.database.chat.meInUsernameColor = value
                    model.store()
                })) {
                    Text("Me in username color")
                }
            } header: {
                Text("Colors")
            } footer: {
                Text("Border is fairly CPU intensive. Disable for less power usage.")
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            SettingsToolbar()
        }
    }
}
