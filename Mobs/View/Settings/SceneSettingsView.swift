import SwiftUI
import UniformTypeIdentifiers

struct SceneSettingsView: View {
    var index: Int
    @ObservedObject var model: Model
    @State private var widgets: [String] = []
    @State private var showingAdd = false
    @State private var selected = "Sub goal"

    var scene: SettingsScene {
        get {
            model.settings.database.scenes[index]
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    scene.name
                }, set: { value in
                    scene.name = value
                    model.store()
                    model.numberOfScenes += 0
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
