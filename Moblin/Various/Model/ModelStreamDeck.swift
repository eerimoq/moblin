import StreamDeckKit
import SwiftUI

class StreamDeck: ObservableObject {
    @Published var isDeviceDriverInstalled: Bool = true
    @Published var streamDeck: SettingsStreamDeck?
}

private struct StreamDeckKeyItemView: View {
    let model: Model
    let index: Int
    @ObservedObject var key: SettingsStreamDeckKey

    var body: some View {
        StreamDeckKeyView { pressed in
            model.handleControllerFunction(buttonId: "sd:\(index)",
                                           function: key.function,
                                           functionData: key.functionData,
                                           pressed: pressed)
        } content: {
            Text(key.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(key.colorColor)
        }
    }
}

private struct StreamDeckView: View {
    let model: Model
    @ObservedObject var streamDeck: StreamDeck

    var body: some View {
        if let streamDeck = streamDeck.streamDeck {
            StreamDeckLayout {
                StreamDeckKeyAreaLayout { index in
                    if index < streamDeck.keys.count {
                        StreamDeckKeyItemView(model: model,
                                              index: index,
                                              key: streamDeck.keys[index])
                    }
                }
            } windowArea: {}
        } else {
            StreamDeckLayout {
                StreamDeckKeyAreaLayout { _ in
                    StreamDeckKeyView { _ in
                    } content: {
                        Text("")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.white)
                    }
                }
            } windowArea: {}
        }
    }
}

extension Model {
    func setupStreamDeck() {
        #if !targetEnvironment(macCatalyst)
        guard isPad() else {
            return
        }
        StreamDeckSession.setUp(newDeviceHandler: {
            $0.render(StreamDeckView(model: self, streamDeck: self.streamDeck))
        })
        updateIsStreamDeckDeviceDriverInstalled()
        #endif
    }

    func setSelectedStreamDeck() {
        let streamDecks = database.streamDecks
        streamDeck.streamDeck = streamDecks.streamDecks.first(where: {
            $0.id == streamDecks.selectedId
        })
        if streamDeck.streamDeck == nil {
            streamDecks.selectedId = nil
        }
    }

    func updateIsStreamDeckDeviceDriverInstalled() {
        guard isPad() else {
            return
        }
        streamDeck.isDeviceDriverInstalled = UIApplication.shared
            .canOpenURL(URL(string: "elgato-device-driver://")!)
    }
}
