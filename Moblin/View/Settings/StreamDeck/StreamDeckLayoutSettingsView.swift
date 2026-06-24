import StreamDeckKit
import SwiftUI

private struct StreamDeckSettingsKeyView: View {
    let model: Model
    @ObservedObject var key: SettingsStreamDeckKey

    private func functions() -> [SettingsControllerFunction] {
        SettingsControllerFunction.allCases.filter {
            ![.zoomIn, .zoomOut].contains($0)
        }
    }

    var body: some View {
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
}

private struct StreamDeckKeyView: View {
    @ObservedObject var key: SettingsStreamDeckKey
    let index: Int
    @Binding var selectedIndex: Int
    let size: CGFloat

    var body: some View {
        Button {
            selectedIndex = index
        } label: {
            ZStack {
                key.colorColor
                Text(key.text)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(alignment: .center)
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 10))
            .overlay(
                RoundedRectangle(cornerRadius: size / 10)
                    .stroke(.blue, lineWidth: index == selectedIndex ? 5 : 2)
            )
        }
        .buttonStyle(.borderless)
    }
}

private struct StreamDeckMiniView: View {
    static let size = 55.0
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    private func key(index: Int) -> some View {
        StreamDeckKeyView(key: keys[index],
                          index: index,
                          selectedIndex: $selectedIndex,
                          size: Self.size)
    }

    var body: some View {
        VStack {
            HCenter {
                key(index: 0)
                key(index: 1)
                key(index: 2)
            }
            HCenter {
                key(index: 3)
                key(index: 4)
                key(index: 5)
            }
        }
    }
}

private struct StreamDeckClassicView: View {
    static let size = 45.0
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    private func key(index: Int) -> some View {
        StreamDeckKeyView(key: keys[index],
                          index: index,
                          selectedIndex: $selectedIndex,
                          size: Self.size)
    }

    var body: some View {
        VStack {
            HCenter {
                key(index: 0)
                key(index: 1)
                key(index: 2)
                key(index: 3)
                key(index: 4)
            }
            HCenter {
                key(index: 5)
                key(index: 6)
                key(index: 7)
                key(index: 8)
                key(index: 9)
            }
            HCenter {
                key(index: 10)
                key(index: 11)
                key(index: 12)
                key(index: 13)
                key(index: 14)
            }
        }
    }
}

private struct StreamDeckXlView: View {
    static let size = 30.0
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    private func key(index: Int) -> some View {
        StreamDeckKeyView(key: keys[index],
                          index: index,
                          selectedIndex: $selectedIndex,
                          size: Self.size)
    }

    var body: some View {
        VStack {
            HCenter {
                key(index: 0)
                key(index: 1)
                key(index: 2)
                key(index: 3)
                key(index: 4)
                key(index: 5)
                key(index: 6)
                key(index: 7)
            }
            HCenter {
                key(index: 8)
                key(index: 9)
                key(index: 10)
                key(index: 11)
                key(index: 12)
                key(index: 13)
                key(index: 14)
                key(index: 15)
            }
            HCenter {
                key(index: 16)
                key(index: 17)
                key(index: 18)
                key(index: 19)
                key(index: 20)
                key(index: 21)
                key(index: 22)
                key(index: 23)
            }
            HCenter {
                key(index: 24)
                key(index: 25)
                key(index: 26)
                key(index: 27)
                key(index: 28)
                key(index: 29)
                key(index: 30)
                key(index: 31)
            }
        }
    }
}

private struct StreamDeckLayoutSettingsView: View {
    let model: Model
    @ObservedObject var layout: SettingsStreamDeckLayout
    @State var selectedIndex: Int = 0

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $layout.name)
                }
                Section {
                    Picker("Model", selection: $layout.model) {
                        ForEach(SettingsStreamDeckModel.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .onChange(of: layout.model) { _ in
                        selectedIndex = 0
                    }
                }
                Section {
                    switch layout.model {
                    case .mini:
                        StreamDeckMiniView(keys: $layout.keys, selectedIndex: $selectedIndex)
                    case .classic:
                        StreamDeckClassicView(keys: $layout.keys, selectedIndex: $selectedIndex)
                    case .xl:
                        StreamDeckXlView(keys: $layout.keys, selectedIndex: $selectedIndex)
                    }
                }
                Section {
                    ForEach(layout.keys) { key in
                        if layout.keys.firstIndex(where: { $0 === key }) == selectedIndex {
                            StreamDeckSettingsKeyView(model: model, key: key)
                        }
                    }
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
                        StreamDeckLayoutSettingsView(model: model, layout: streamDeck)
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
