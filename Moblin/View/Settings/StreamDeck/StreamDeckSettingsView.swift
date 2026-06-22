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
                Text("Key \(index + 1)")
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
    @ObservedObject var layout: SettingsStreamDeckLayout

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $layout.name)
                }
                Section {
                    List {
                        ForEach(layout.keys) { key in
                            if let index = layout.keys.firstIndex(where: { $0 === key }) {
                                HStack {
                                    DraggableItemPrefixView()
                                    StreamDeckSettingsKeyView(model: model, index: index, key: key)
                                    Spacer()
                                }
                            }
                        }
                        .onMove { froms, to in
                            layout.keys.move(fromOffsets: froms, toOffset: to)
                        }
                    }
                } header: {
                    Text("Keys")
                }
            }
            .navigationTitle("Stream deck")
        } label: {
            Text(layout.name)
        }
    }
}

struct StreamDecksSettingsView: View {
    let model: Model
    @ObservedObject var streamDeck: StreamDeck
    @ObservedObject var streamDecks: SettingsStreamDecks

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "StreamDeck")
                }
            }
            if !streamDeck.isDeviceDriverInstalled {
                Section {
                    Text("""
                    ⚠️ Download and install Stream Deck Connect from the App Store, and \
                    then enable the Stream Deck Device Driver in its settings.
                    """)
                }
            }
            Section {
                Picker("Current", selection: $streamDecks.selectedId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(streamDecks.layouts) {
                        Text($0.name)
                            .tag($0.id as UUID?)
                    }
                }
                .onChange(of: streamDecks.selectedId) { _ in
                    model.setSelectedStreamDeck()
                }
            }
            Section {
                List {
                    ForEach(streamDecks.layouts) { streamDeck in
                        StreamDeckSettingsView(model: model, layout: streamDeck)
                    }
                    .onMove { froms, to in
                        streamDecks.layouts.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        streamDecks.layouts.remove(atOffsets: offsets)
                        model.setSelectedStreamDeck()
                    }
                }
                CreateButtonView {
                    let streamDeck = SettingsStreamDeckLayout()
                    streamDeck.name = makeUniqueName(name: SettingsStreamDeckLayout.baseName,
                                                     existingNames: streamDecks.layouts)
                    streamDecks.layouts.append(streamDeck)
                }
            } header: {
                Text("Layouts")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String("a layout"))
            }
        }
        .navigationTitle("Stream deck")
    }
}
