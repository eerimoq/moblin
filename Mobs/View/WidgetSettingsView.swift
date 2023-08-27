import SwiftUI

struct WidgetSettingsView: View {
    private var index: Int
    @ObservedObject var model: Model
    let types = ["Text", "Image", "Video", "Camera", "Chat", "Recording", "Webview"]
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }

    func getType() -> String {
        self.model.settings.database.widgets[self.index].type
    }
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.widgets[self.index].name
                }, set: { value in
                    self.model.settings.database.widgets[self.index].name = value
                    self.model.settings.store()
                    self.model.numberOfWidgets += 0
                }))
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    self.model.settings.database.widgets[self.index].type
                }, set: { value in
                    self.model.settings.database.widgets[self.index].type = value
                    self.model.settings.store()
                    self.model.numberOfWidgets += 0
                })) {
                    ForEach(types, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if self.getType() == "Text" {
                Section("Format string") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.widgets[self.index].text.formatString
                    }, set: { value in
                        self.model.settings.database.widgets[self.index].text.formatString = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Image" {
                Section("URL") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.widgets[self.index].image.url
                    }, set: { value in
                        self.model.settings.database.widgets[self.index].image.url = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Video" {
                Section("URL") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.widgets[self.index].video.url
                    }, set: { value in
                        self.model.settings.database.widgets[self.index].video.url = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Camera" {
                Section("Direction") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.widgets[self.index].camera.direction
                    }, set: { value in
                        self.model.settings.database.widgets[self.index].camera.direction = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Webview" {
                Section("URL") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.widgets[self.index].webview.url
                    }, set: { value in
                        self.model.settings.database.widgets[self.index].webview.url = value
                        self.model.settings.store()
                    }))
                }
            }
        }
        .navigationTitle("Widget")
    }
}

struct WidgetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetSettingsView(index: 0, model: Model())
    }
}
