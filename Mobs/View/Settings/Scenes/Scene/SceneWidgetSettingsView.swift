import SwiftUI

struct SceneWidgetSettingsView: View {
    @ObservedObject private var model: Model
    private var widget: SettingsSceneWidget
    private var name: String
    
    init(model: Model, widget: SettingsSceneWidget, name: String) {
        self.model = model
        self.widget = widget
        self.name = name
    }
    
    func submitX(value: String) {
        if let value = Double(value) {
            widget.x = min(max(value, 0), 99)
            model.store()
            model.sceneUpdated()
        }
    }
    
    func submitY(value: String) {
        if let value = Double(value) {
            widget.y = min(max(value, 0), 99)
            model.store()
            model.sceneUpdated()
        }
    }
    
    func submitW(value: String) {
        if let value = Double(value) {
            widget.width = min(max(value, 1), 100)
            model.store()
            model.sceneUpdated()
        }
    }
    
    func submitH(value: String) {
        if let value = Double(value) {
            widget.height = min(max(value, 1), 100)
            model.store()
            model.sceneUpdated()
        }
    }
    
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(title: "X", value: "\(widget.x)", onSubmit: submitX)) {
                    TextItemView(name: "X", value: "\(widget.x)")
                }
                NavigationLink(destination: TextEditView(title: "Y", value: "\(widget.y)", onSubmit: submitY)) {
                    TextItemView(name: "Y", value: "\(widget.y)")
                }
                NavigationLink(destination: TextEditView(title: "Width", value: "\(widget.width)", onSubmit: submitW)) {
                    TextItemView(name: "Width", value: "\(widget.width)")
                }
                NavigationLink(destination: TextEditView(title: "Height", value: "\(widget.height)", onSubmit: submitH)) {
                    TextItemView(name: "Height", value: "\(widget.height)")
                }
            } footer: {
                Text("Only full screen cameras and video effects are supported.")
            }
        }
        .navigationTitle("Widget")
    }
}
