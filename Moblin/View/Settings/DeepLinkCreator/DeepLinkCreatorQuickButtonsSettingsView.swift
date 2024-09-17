import SwiftUI

struct DeepLinkCreatorQuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    private var quickButtons: DeepLinkCreatorQuickButtons {
        return model.database.deepLinkCreator!.quickButtons!
    }

    var body: some View {
        Form {
            Section {
                Toggle("Scroll", isOn: Binding(get: {
                    quickButtons.enableScroll
                }, set: { value in
                    quickButtons.enableScroll = value
                }))
                Toggle("Two columns", isOn: Binding(get: {
                    quickButtons.twoColumns
                }, set: { value in
                    quickButtons.twoColumns = value
                }))
                Toggle("Show name", isOn: Binding(get: {
                    quickButtons.showName
                }, set: { value in
                    quickButtons.showName = value
                }))
            } header: {
                Text("Appearence")
            }
            Section {
                List {
                    ForEach(quickButtons.buttons) { button in
                        Toggle(isOn: Binding(get: {
                            button.enabled
                        }, set: { value in
                            button.enabled = value
                        })) {
                            HStack {
                                DraggableItemPrefixView()
                                if let globalButton = model.getGlobalButton(type: button.type) {
                                    IconAndTextView(
                                        image: globalButton.systemImageNameOff,
                                        text: globalButton.name,
                                        longDivider: true
                                    )
                                } else {
                                    Text("Unknown")
                                }
                                Spacer()
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        quickButtons.buttons.move(fromOffsets: froms, toOffset: to)
                    })
                }
            }
        }
        .navigationTitle("Quick buttons")
        .toolbar {
            SettingsToolbar()
        }
    }
}
