import SwiftUI

struct TallyState {
    let message: String
    let background: RgbColor
    let foreground: RgbColor
}

@MainActor
class Tally: ObservableObject {
    @Published private(set) var state: TallyState?

    func show(message: String, background: RgbColor, foreground: RgbColor) {
        state = TallyState(message: message, background: background, foreground: foreground)
    }

    func hide() {
        state = nil
    }
}
