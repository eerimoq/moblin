import StreamDeckKit
import SwiftUI

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
    @ObservedObject var streamDeck: SettingsStreamDeck

    var body: some View {
        StreamDeckLayout {
            StreamDeckKeyAreaLayout { index in
                if index < streamDeck.keys.count {
                    StreamDeckKeyItemView(model: model,
                                          index: index,
                                          key: streamDeck.keys[index])
                }
            }
        } windowArea: {}
    }
}

extension Model {
    func setupStreamDeck() {
        #if !targetEnvironment(macCatalyst)
        guard isPad() else {
            return
        }
        StreamDeckSession.setUp(newDeviceHandler: {
            $0.render(StreamDeckView(model: self, streamDeck: self.database.streamDeck))
        })
        #endif
    }
}
