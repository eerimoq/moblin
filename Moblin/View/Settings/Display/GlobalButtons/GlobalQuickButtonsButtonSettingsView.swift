import SwiftUI

struct GlobalQuickButtonsButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var name: String
    var color: RgbColor
    @State var red: Float
    @State var green: Float
    @State var blue: Float
    let onChange: () -> Void

    var body: some View {
        Form {
            Section {
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
                    .onChange(of: red) { value in
                        color.red = Int(value)
                        onChange()
                    }
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
                    .onChange(of: green) { value in
                        color.green = Int(value)
                        onChange()
                    }
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
                    .onChange(of: blue) { value in
                        color.blue = Int(value)
                        onChange()
                    }
                    Text(String(Int(blue)))
                        .frame(width: 35)
                }
            } header: {
                Text("Background")
            }
        }
        .navigationTitle(name)
        .toolbar {
            SettingsToolbar()
        }
    }
}
