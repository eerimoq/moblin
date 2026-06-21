import SwiftUI

private struct StreamDeckSettingsKeyView: View {
    let model: Model
    let index: Int
    @ObservedObject var key: SettingsStreamDeckKey

    private func functions() -> [SettingsControllerFunction] {
        SettingsControllerFunction.allCases.filter {
            ![.zoomIn, .zoomOut].contains($0)
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $key.function,
                                     functionData: $key.functionData)
                TextEditNavigationView(title: "Text",
                                       value: key.text,
                                       onSubmit: {
                                           key.text = $0
                                       })
                ColorPicker("Color", selection: $key.colorColor, supportsOpacity: false)
                    .onChange(of: key.colorColor) { color in
                        key.color = color.toRgb() ?? .black
                    }
            }
        } label: {
            HStack {
                Text("Key \(index)")
                Spacer()
                Text(key.function.toString(
                    sceneName: model.getSceneName(id: key.functionData.sceneId ?? .init()),
                    widgetName: model.getWidgetName(id: key.functionData.widgetId ?? .init())
                ))
                .foregroundStyle(key.function.color())
            }
        }
    }
}

struct StreamDeckSettingsView: View {
    let model: Model
    @ObservedObject var streamDeck: SettingsStreamDeck

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(streamDeck.keys) { key in
                        if let index = streamDeck.keys.firstIndex(where: { $0 === key }) {
                            HStack {
                                DraggableItemPrefixView()
                                StreamDeckSettingsKeyView(model: model, index: index, key: key)
                                Spacer()
                            }
                        }
                    }
                    .onMove { froms, to in
                        streamDeck.keys.move(fromOffsets: froms, toOffset: to)
                    }
                }
            } header: {
                Text("Keys")
            }
        }
        .navigationTitle("Stream deck")
    }
}
