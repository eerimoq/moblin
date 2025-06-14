import SwiftUI

struct MultiLineTextField: View {
    @Binding var value: String
    @FocusState var focusedField: Bool?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TextField("", text: $value, axis: .vertical)
                .padding(.trailing, 30)
                .focused($focusedField, equals: true)
            if !value.isEmpty {
                Button {
                    value = ""
                    focusedField = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(uiColor: .gray))
                        .opacity(0.5)
                }
                .padding([.top], 1)
                .padding([.trailing], 5)
                .buttonStyle(.plain)
            }
        }
    }
}
