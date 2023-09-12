import SwiftUI

struct SceneWidgetSettingsView: View {
    @ObservedObject private var model: Model
    private var widget: SettingsSceneWidget
    private var name: String
    private var isImage: Bool
    
    init(model: Model, widget: SettingsSceneWidget, name: String) {
        self.model = model
        self.widget = widget
        self.name = name
        if let widget = model.findWidget(id: widget.widgetId) {
            self.isImage = widget.type == .image
        } else {
            logger.error("Unable to find widget type")
            self.isImage = false
        }
    }
    
    func submitX(value: String) {
        if let value = Double(value) {
            widget.x = min(max(value, 0), 99)
            model.store()
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }
    
    func submitY(value: String) {
        if let value = Double(value) {
            widget.y = min(max(value, 0), 99)
            model.store()
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }
    
    func submitW(value: String) {
        if let value = Double(value) {
            widget.width = min(max(value, 1), 100)
            model.store()
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }
    
    func submitH(value: String) {
        if let value = Double(value) {
            widget.height = min(max(value, 1), 100)
            model.store()
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }
    
    var body: some View {
        Form {
            Section {
                if isImage {
                    NavigationLink(destination: TextEditView(title: "X", value: String(widget.x), onSubmit: submitX)) {
                        TextItemView(name: "X", value: String(widget.x))
                    }
                    NavigationLink(destination: TextEditView(title: "Y", value: String(widget.y), onSubmit: submitY)) {
                        TextItemView(name: "Y", value: String(widget.y))
                    }
                    NavigationLink(destination: TextEditView(title: "Width", value: String(widget.width), onSubmit: submitW)) {
                        TextItemView(name: "Width", value: String(widget.width))
                    }
                    NavigationLink(destination: TextEditView(title: "Height", value: String(widget.height), onSubmit: submitH)) {
                        TextItemView(name: "Height", value: String(widget.height))
                    }
                } else {
                    TextItemView(name: "X", value: String(widget.x))
                    TextItemView(name: "Y", value: String(widget.y))
                    TextItemView(name: "Width", value: String(widget.width))
                    TextItemView(name: "Height", value: String(widget.height))
                }
            } footer: {
                Text("Only full screen cameras and video effects are supported.")
            }
        }
        .navigationTitle("Widget")
    }
}
