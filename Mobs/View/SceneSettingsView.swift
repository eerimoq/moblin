import SwiftUI
import UniformTypeIdentifiers

struct DragRelocateDelegate: DropDelegate {
    func validateDrop(info: DropInfo) -> Bool {
        print("validate drop")
        return true
    }
    
    func performDrop(info: DropInfo) -> Bool {
        print("Perform drop")
        return true
    }
    
    func dropEntered(info: DropInfo) {
        print("Drop entered")
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        print("Drop updated")
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        print("Drop exited")
    }
}

struct SceneSettingsView: View {
    @ObservedObject var model: Model
    @State private var draggingItem: String? = nil
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: $model.sceneName)
            }
            Section("Widgets") {
                List {
                    ForEach($model.sceneWidgets, id: \.self, editActions: .move) { $widget in
                        Text(widget)
                    }.onDelete(perform: { offsets in
                        print("delete")
                    })
                }
                AddButtonView(action: {
                    print("Add widget")
                })
            }
        }
        .navigationTitle("Scene")
    }
}

struct SceneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SceneSettingsView(model: Model())
    }
}
