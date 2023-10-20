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
    var toolbar: Toolbar
    var title: String
    var color: RgbColor
    @State var red: Float
    @State var green: Float
    @State var blue: Float

    init(model: Model, toolbar: Toolbar, title: String, color: RgbColor) {
        self.model = model
        self.toolbar = toolbar
        self.title = title
        self.color = color
        red = Float(color.red)
        green = Float(color.green)
        blue = Float(color.blue)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Circle()
                        .frame(width: 50, height: 50)
                        .foregroundColor(Color(
                            red: Double(red) / 255,
                            green: Double(green) / 255,
                            blue: Double(blue) / 255
                        ))
                        .overlay(
                            Circle()
                                .stroke(.secondary, lineWidth: 2)
                        )
                    Spacer()
                }
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
                    Text(String(Int(blue)))
                        .frame(width: 35)
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            toolbar
        }
    }
}

struct LocalOverlaysChatSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    init(model: Model, toolbar: Toolbar) {
        self.model = model
        self.toolbar = toolbar
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
            Section("General") {
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
                    model.database.chat!.bold
                }, set: { value in
                    model.database.chat!.bold = value
                    model.store()
                })) {
                    Text("Bold")
                }
            }
            Section("Colors") {
                NavigationLink(destination: ColorEditView(
                    model: model,
                    toolbar: toolbar,
                    title: "Username",
                    color: model.database.chat!.usernameColor
                )) {
                    HStack {
                        Text("Username")
                        Spacer()
                        ColorCircle(color: model.database.chat!.usernameColor.color())
                    }
                }
                NavigationLink(destination: ColorEditView(
                    model: model,
                    toolbar: toolbar,
                    title: "Message",
                    color: model.database.chat!.messageColor
                )) {
                    HStack {
                        Text("Message")
                        Spacer()
                        ColorCircle(color: model.database.chat!.messageColor.color())
                    }
                }
                NavigationLink(destination: ColorEditView(
                    model: model,
                    toolbar: toolbar,
                    title: "Background",
                    color: model.database.chat!.backgroundColor
                )) {
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
                NavigationLink(destination: ColorEditView(
                    model: model,
                    toolbar: toolbar,
                    title: "Shadow",
                    color: model.database.chat!.shadowColor
                )) {
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
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            toolbar
        }
    }
}
