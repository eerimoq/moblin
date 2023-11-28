import SwiftUI

struct ImageItemView: View {
    var name: String
    var image: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: image)
        }
    }
}

struct ButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var button: SettingsButton
    @State var selection: String
    @State var selectedWidget: Int

    func submitName(name: String) {
        button.name = name
        model.store()
    }

    func onSystemImageNameOn(name: String) {
        button.systemImageNameOn = name
        model.store()
    }

    func onSystemImageNameOff(name: String) {
        button.systemImageNameOff = name
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: button.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: button.name)
            }
            Section("Type") {
                Picker("", selection: $selection) {
                    ForEach(buttonTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                .onChange(of: selection) { type in
                    button.type = SettingsButtonType(rawValue: type)!
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            switch selection {
            case "Widget":
                Section("Widget") {
                    Picker("", selection: $selectedWidget) {
                        ForEach(model.database.widgets) { widget in
                            IconAndTextView(
                                image: widgetImage(widget: widget),
                                text: widget.name
                            )
                            .tag(model.database.widgets.firstIndex(of: widget)!)
                        }
                    }
                    .onChange(of: selectedWidget) { index in
                        button.widget.widgetId = model.database.widgets[index].id
                        model.store()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            default:
                EmptyView()
            }
            Section("Icons") {
                NavigationLink(destination: ButtonImagePickerSettingsView(
                    title: String(localized: "On"),
                    selectedImageSystemName: button.systemImageNameOn,
                    onChange: onSystemImageNameOn
                )) {
                    ImageItemView(name: String(localized: "On"), image: button.systemImageNameOn)
                }
                NavigationLink(destination: ButtonImagePickerSettingsView(
                    title: String(localized: "Off"),
                    selectedImageSystemName: button.systemImageNameOff,
                    onChange: onSystemImageNameOff
                )) {
                    ImageItemView(name: String(localized: "Off"), image: button.systemImageNameOff)
                }
            }
        }
        .navigationTitle("Button")
        .toolbar {
            SettingsToolbar()
        }
    }
}
