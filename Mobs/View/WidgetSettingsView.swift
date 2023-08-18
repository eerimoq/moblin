import SwiftUI

struct WidgetSettingsView: View {
    @ObservedObject var model: Model
    let kinds = ["Text", "Image", "Video", "Camera", "Chat", "Recording", "Webview"]
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: $model.widgetName)
            }
            Section("Kind") {
                Picker("", selection: $model.widgetSelectedKind) {
                    ForEach(kinds, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if self.model.widgetSelectedKind == "Text" {
                Section("Format string") {
                    TextField("", text: $model.widgetTextFormatString)
                }
            } else if self.model.widgetSelectedKind == "Image" {
                Section("URL") {
                    TextField("", text: $model.widgetImageUrl)
                }
            } else if self.model.widgetSelectedKind == "Video" {
                Section("URL") {
                    TextField("", text: $model.widgetVideoUrl)
                }
            } else if self.model.widgetSelectedKind == "Camera" {
                Section("Direction") {
                    TextField("", text: $model.widgetCameraDirection)
                }
            } else if self.model.widgetSelectedKind == "Chat" {
                Section("Channel name") {
                    TextField("", text: $model.widgetChatChannelName)
                }
            } else if self.model.widgetSelectedKind == "Webview" {
                Section("URL") {
                    TextField("", text: $model.widgetWebviewUrl)
                }
            }
        }
        .navigationTitle("Widget")
    }
}

struct WidgetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetSettingsView(model: Model())
    }
}
