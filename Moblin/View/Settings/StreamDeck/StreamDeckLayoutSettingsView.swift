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
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    var body: some View {
        let size = 55.0
        VStack {
            HCenter {
                StreamDeckKeyView(key: keys[0], index: 0, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[1], index: 1, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[2], index: 2, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[3], index: 3, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[4], index: 4, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[5], index: 5, selectedIndex: $selectedIndex, size: size)
            }
        }
    }
}

private struct StreamDeckClassicView: View {
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    var body: some View {
        let size = 45.0
        VStack {
            HCenter {
                StreamDeckKeyView(key: keys[0], index: 0, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[1], index: 1, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[2], index: 2, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[3], index: 3, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[4], index: 4, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[5], index: 5, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[6], index: 6, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[7], index: 7, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[8], index: 8, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[9], index: 9, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[10], index: 10, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[11], index: 11, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[12], index: 12, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[13], index: 13, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[14], index: 14, selectedIndex: $selectedIndex, size: size)
            }
        }
    }
}

private struct StreamDeckXlView: View {
    @Binding var keys: [SettingsStreamDeckKey]
    @Binding var selectedIndex: Int

    var body: some View {
        let size = 30.0
        VStack {
            HCenter {
                StreamDeckKeyView(key: keys[0], index: 0, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[1], index: 1, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[2], index: 2, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[3], index: 3, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[4], index: 4, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[5], index: 5, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[6], index: 6, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[7], index: 7, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[8], index: 8, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[9], index: 9, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[10], index: 10, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[11], index: 11, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[12], index: 12, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[13], index: 13, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[14], index: 14, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[15], index: 15, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[16], index: 16, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[17], index: 17, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[18], index: 18, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[19], index: 19, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[20], index: 20, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[21], index: 21, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[22], index: 22, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[23], index: 23, selectedIndex: $selectedIndex, size: size)
            }
            HCenter {
                StreamDeckKeyView(key: keys[24], index: 24, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[25], index: 25, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[26], index: 26, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[27], index: 27, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[28], index: 28, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[29], index: 29, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[30], index: 30, selectedIndex: $selectedIndex, size: size)
                StreamDeckKeyView(key: keys[31], index: 31, selectedIndex: $selectedIndex, size: size)
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
                    if selectedIndex < layout.keys.count {
                        StreamDeckSettingsKeyView(model: model, key: layout.keys[selectedIndex])
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
