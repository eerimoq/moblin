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
    @ObservedObject var streamDeck: SettingsStreamDeck

    var body: some View {
        NavigationLink {
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
        } label: {
            Text(streamDeck.name)
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
                    ⚠️ Stream Deck device driver is not installed. Download and install \
                    Stream Deck Connect from the App Store, and then enable the Stream \
                    Deck Device Driver in its settings.
                    """)
                }
            }
            Section {
                Picker("Current", selection: $streamDecks.selectedId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(streamDecks.streamDecks) {
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
                    ForEach(streamDecks.streamDecks) { streamDeck in
                        StreamDeckSettingsView(model: model, streamDeck: streamDeck)
                    }
                    .onMove { froms, to in
                        streamDecks.streamDecks.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        streamDecks.streamDecks.remove(atOffsets: offsets)
                        model.setSelectedStreamDeck()
                    }
                }
                CreateButtonView {
                    let streamDeck = SettingsStreamDeck()
                    streamDeck.name = makeUniqueName(name: SettingsStreamDeck.baseName,
                                                     existingNames: streamDecks.streamDecks)
                    streamDecks.streamDecks.append(streamDeck)
                }
            } header: {
                Text("Stream decks")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String("a stream deck"))
            }
        }
        .navigationTitle("Stream deck")
    }
}
