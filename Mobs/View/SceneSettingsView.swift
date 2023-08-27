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
    private var index: Int
    @ObservedObject private var model: Model
    @State var widgets: [String] = []
    @State private var showingAdd = false
    @State private var selected = "Sub goal"
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }
    
    var scene: SettingsScene {
        get {
            model.settings.database.scenes[self.index]
        }
    }
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    scene.name
                }, set: { value in
                    scene.name = value
                    self.model.store()
                    self.model.numberOfScenes += 0
                }))
            }
            Section("Widgets") {
                List {
                    ForEach($widgets, id: \.self, editActions: .move) { $widget in
                        Text(widget)
                    }.onDelete(perform: { offsets in
                        print("delete")
                    })
                }
                AddButtonView(action: {
                    showingAdd = true
                }).popover(isPresented: $showingAdd) {
                    VStack {
                        Form {
                            Section("Name") {
                                Picker("", selection: $selected) {
                                    ForEach(model.widgets, id: \.self) {
                                        Text($0)
                                    }
                                }
                                .pickerStyle(.inline)
                                .labelsHidden()
                            }
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAdd = false
                            }, label: {
                                Text("Cancel")
                            })
                            Spacer()
                            Button(action: {
                                showingAdd = false
                            }, label: {
                                Text("Done")
                            })
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Scene")
    }
}

struct SceneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SceneSettingsView(index: 0, model: Model())
    }
}
