@testable import Moblin
import Testing
import UIKit

@MainActor
private func makeView() -> ChatLineUiView {
    let view = ChatLineUiView()
    view.setContent(ChatLineContent(
        items: [.text("user: this is a fairly long chat message that wraps over several lines",
                      ChatLineTextStyle(color: .white))],
        fontSize: 17
    ))
    return view
}

@MainActor
private func render(_ view: ChatLineUiView) -> Data? {
    view.layoutIfNeeded()
    return UIGraphicsImageRenderer(size: view.bounds.size).pngData { context in
        view.layer.render(in: context.cgContext)
    }
}

@MainActor
private func setSize(_ view: ChatLineUiView, availableWidth: CGFloat) {
    view.frame = CGRect(origin: .zero, size: view.size(availableWidth: availableWidth))
    view.layoutIfNeeded()
}

struct ChatLineViewSuite {
    @Test
    @MainActor
    func renderingIsTheSameAfterWidthChangedBackWithoutRemeasuring() {
        let reference = makeView()
        setSize(reference, availableWidth: 400)
        let resized = makeView()
        setSize(resized, availableWidth: 400)
        let wideSize = resized.bounds.size
        setSize(resized, availableWidth: 250)
        #expect(resized.bounds.size != wideSize)
        resized.frame = CGRect(origin: .zero, size: wideSize)
        #expect(render(resized) == render(reference))
    }
}
