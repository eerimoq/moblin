import SwiftUI

struct TextButtonView: View {
    private let localizedTitle: LocalizedStringKey?
    private let stringTitle: String?
    private let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        localizedTitle = title
        stringTitle = nil
        self.action = action
    }

    init(title: String, action: @escaping () -> Void) {
        localizedTitle = nil
        stringTitle = title
        self.action = action
    }

    var body: some View {
        HStack {
            Button {
                action()
            } label: {
                HStack {
                    Text("")
                    Spacer()
                    if let localizedTitle {
                        Text(localizedTitle)
                    } else if let stringTitle {
                        Text(stringTitle)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
        }
    }
}
