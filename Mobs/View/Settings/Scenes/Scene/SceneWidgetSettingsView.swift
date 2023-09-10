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
        if let value = Int(value) {
            widget.x = min(max(value, 0), 99)
            model.store()
        }
    }
    
    func submitY(value: String) {
        if let value = Int(value) {
            widget.y = min(max(value, 0), 99)
            model.store()
        }
    }
    
    func submitW(value: String) {
        if let value = Int(value) {
            widget.w = min(max(value, 1), 100)
            model.store()
        }
    }
    
    func submitH(value: String) {
        if let value = Int(value) {
            widget.h = min(max(value, 1), 100)
            model.store()
        }
    }
    
    var body: some View {
        Form {
            Section {
                //NavigationLink(destination: TextEditView(title: "X", value: "\(widget.x)", onSubmit: submitX)) {
                TextItemView(name: "X", value: "\(widget.x)")
                //}
                //NavigationLink(destination: TextEditView(title: "Y", value: "\(widget.y)", onSubmit: submitY)) {
                TextItemView(name: "Y", value: "\(widget.y)")
                //}
                //NavigationLink(destination: TextEditView(title: "Width", value: "\(widget.w)", onSubmit: submitW)) {
                TextItemView(name: "Width", value: "\(widget.w)")
                //}
                //NavigationLink(destination: TextEditView(title: "Height", value: "\(widget.h)", onSubmit: submitH)) {
                TextItemView(name: "Height", value: "\(widget.h)")
                //}
            } footer: {
                Text("Only full screen widgets are supported.")
            }
        }
        .navigationTitle("Widget")
    }
}
