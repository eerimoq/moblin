import SwiftUI

var sensitiveUrlFooter =
    "Do not share your URL with anyone or they can hijack your channel!"

struct SensitiveUrlEditView: View {
    @State var value: String
    var onSubmit: (String) -> Void
    @State var show: Bool = false

    var body: some View {
        Form {
            Section {
                if show {
                    TextField("", text: $value)
                        .onSubmit {
                            onSubmit(value.trim())
                        }
                } else {
                    Text(replaceSensitive(value: value, sensitive: true))
                        .lineLimit(1)
                }
                HStack {
                    Spacer()
                    if show {
                        Button("Hide sensitive URL") {
                            show = false
                        }
                    } else {
                        Button("Show sensitive URL", role: .destructive) {
                            show = true
                        }
                    }
                    Spacer()
                }
            } footer: {
                Text(sensitiveUrlFooter)
            }
        }
        .navigationTitle("URL")
    }
}
