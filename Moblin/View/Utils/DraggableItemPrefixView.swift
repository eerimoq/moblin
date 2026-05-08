import SwiftUI

struct DraggableItemPrefixView: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
    }
}

struct DraggableItemTextView: View {
    let name: String

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            Text(name)
            Spacer()
        }
    }
}
