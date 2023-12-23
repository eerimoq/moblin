import SwiftUI

struct QuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Scroll", isOn: Binding(get: {
                    model.database.quickButtons!.enableScroll
                }, set: { value in
                    model.database.quickButtons!.enableScroll = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
                Toggle("Two columns", isOn: Binding(get: {
                    model.database.quickButtons!.twoColumns
                }, set: { value in
                    model.database.quickButtons!.twoColumns = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
                Toggle("Show name", isOn: Binding(get: {
                    model.database.quickButtons!.showName
                }, set: { value in
                    model.database.quickButtons!.showName = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
            } header: {
                Text("Appearence")
            }
            Section {
                List {
                    ForEach(model.database.globalButtons!) { button in
                        Toggle(isOn: Binding(get: {
                            button.enabled!
                        }, set: { value in
                            button.enabled = value
                            model.store()
                            model.updateButtonStates()
                        })) {
                            HStack {
                                DraggableItemPrefixView()
                                IconAndTextView(
                                    image: button.systemImageNameOff,
                                    text: button.name
                                )
                                Spacer()
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        model.database.globalButtons!.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                }
            } header: {
                Text("Buttons")
            }
        }
        .navigationTitle("Buttons")
        .toolbar {
            SettingsToolbar()
        }
    }
}
