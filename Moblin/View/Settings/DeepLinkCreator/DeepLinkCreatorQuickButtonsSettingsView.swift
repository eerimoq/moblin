import SwiftUI

private struct DeepLinkCreatorQuickButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: DeepLinkCreatorQuickButton

    var body: some View {
        Toggle(isOn: $button.enabled) {
            HStack {
                DraggableItemPrefixView()
                if let globalButton = model.getGlobalButton(type: button.type) {
                    IconAndTextView(
                        image: globalButton.imageOff,
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
}

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
                Text("Appearance")
            }
            Section {
                List {
                    ForEach(quickButtons.buttons) { button in
                        DeepLinkCreatorQuickButtonSettingsView(button: button)
                    }
                    .onMove { froms, to in
                        quickButtons.buttons.move(fromOffsets: froms, toOffset: to)
                    }
                }
            }
        }
        .navigationTitle("Quick buttons")
    }
}
