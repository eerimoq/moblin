import SwiftUI

struct QuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                if model.database.showAllSettings {
                    Toggle("Scroll", isOn: Binding(get: {
                        model.database.quickButtons.enableScroll
                    }, set: { value in
                        model.database.quickButtons.enableScroll = value
                        model.updateQuickButtonStates()
                        model.scrollQuickButtonsToBottom()
                    }))
                    Toggle("Two columns", isOn: Binding(get: {
                        model.database.quickButtons.twoColumns
                    }, set: { value in
                        model.database.quickButtons.twoColumns = value
                        model.updateQuickButtonStates()
                        model.scrollQuickButtonsToBottom()
                    }))
                }
                Toggle("Show name", isOn: Binding(get: {
                    model.database.quickButtons.showName
                }, set: { value in
                    model.database.quickButtons.showName = value
                    model.updateQuickButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
            } header: {
                Text("Appearence")
            } footer: {
                Text("Names are not shown in portrait mode.")
            }
            Section {
                List {
                    ForEach(model.database.globalButtons) { button in
                        if model.database.showAllSettings {
                            NavigationLink {
                                QuickButtonsButtonSettingsView(
                                    button: button,
                                    shortcut: false
                                )
                            } label: {
                                Toggle(isOn: Binding(get: {
                                    button.enabled
                                }, set: { value in
                                    button.enabled = value
                                    model.updateQuickButtonStates()
                                })) {
                                    HStack {
                                        DraggableItemPrefixView()
                                        IconAndTextView(
                                            image: button.systemImageNameOff,
                                            text: button.name,
                                            longDivider: true
                                        )
                                        Spacer()
                                    }
                                }
                            }
                        } else {
                            Toggle(isOn: Binding(get: {
                                button.enabled
                            }, set: { value in
                                button.enabled = value
                                model.updateQuickButtonStates()
                            })) {
                                HStack {
                                    DraggableItemPrefixView()
                                    IconAndTextView(
                                        image: button.systemImageNameOff,
                                        text: button.name,
                                        longDivider: true
                                    )
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        model.database.globalButtons.move(fromOffsets: froms, toOffset: to)
                        model.updateQuickButtonStates()
                        model.sceneUpdated(updateRemoteScene: false)
                    })
                }
            } header: {
                Text("Quick buttons")
            }
        }
        .navigationTitle("Quick buttons")
    }
}
