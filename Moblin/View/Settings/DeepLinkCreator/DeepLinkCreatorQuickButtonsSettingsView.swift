import SwiftUI

struct DeepLinkCreatorQuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var quickButtons: DeepLinkCreatorQuickButtons

    var body: some View {
        Form {
            Section {
                Toggle("Scroll", isOn: $quickButtons.enableScroll)
                Toggle("Two columns", isOn: $quickButtons.twoColumns)
                Toggle("Show name", isOn: $quickButtons.showName)
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
    }
}
