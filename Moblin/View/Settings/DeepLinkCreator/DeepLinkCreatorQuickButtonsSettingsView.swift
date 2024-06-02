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
                    model.store()
                }))
                Toggle("Two columns", isOn: Binding(get: {
                    quickButtons.twoColumns
                }, set: { value in
                    quickButtons.twoColumns = value
                    model.store()
                }))
                Toggle("Show name", isOn: Binding(get: {
                    quickButtons.showName
                }, set: { value in
                    quickButtons.showName = value
                    model.store()
                }))
            } header: {
                Text("Appearence")
            }
            // Section {
            //    List {
            //        ForEach(model.database.globalButtons!) { button in
            //            Toggle(isOn: Binding(get: {
            //                button.enabled!
            //            }, set: { value in
            //                button.enabled = value
            //                model.store()
            //                model.updateButtonStates()
            //            })) {
            //                HStack {
            //                    DraggableItemPrefixView()
            //                    IconAndTextView(
            //                        image: button.systemImageNameOff,
            //                        text: button.name,
            //                        longDivider: true
            //                    )
            //                    Spacer()
            //                }
            //            }
            //            .onMove(perform: { froms, to in
            //                model.database.globalButtons!.move(fromOffsets: froms, toOffset: to)
            //                model.updateButtonStates()
            //                model.sceneUpdated()
            //            })
            //        }
            //    }
            // }
        }
        .navigationTitle("Quick buttons")
        .toolbar {
            SettingsToolbar()
        }
    }
}
