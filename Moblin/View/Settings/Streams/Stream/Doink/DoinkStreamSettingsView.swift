import SwiftUI

private let fallbackMinutes = [1, 2, 3, 5, 10, 15, 20, 30]

struct DoinkEndStreamView: View {
    let model: Model
    let api: DoinkApi
    @State private var presentingEndStream = false

    var body: some View {
        Section {
            TextButtonView("End stream") {
                presentingEndStream = true
            }
            .confirmationDialog("", isPresented: $presentingEndStream) {
                Button("End stream", role: .destructive) {
                    api.endStream {
                        switch $0 {
                        case .success:
                            model.makeToast(title: String(localized: "Ended"))
                        case .authError:
                            break
                        case let .error(message):
                            model
                                .makeErrorToast(title: message ?? String(localized: "Failed to update doink"))
                        }
                    }
                }
            }
        } footer: {
            Text("Ends doink fallback.")
        }
    }
}

struct DoinkStreamSettingsView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    let api: DoinkApi
    @Binding var info: DoinkApiStream?
    let reload: () -> Void
    let logout: () -> Void
    @State private var presentingRotateStreamKey = false

    private func handle<T>(result: DoinkApiResult<T>, onSuccess: (T) -> Void = { _ in }) {
        switch result {
        case let .success(value):
            onSuccess(value)
        case .authError:
            logout()
        case let .error(message):
            model.makeErrorToast(title: message ?? String(localized: "Failed to update doink"))
            reload()
        }
    }

    private func update(change: (inout DoinkApiStream) -> Void) {
        guard var info else {
            return
        }
        change(&info)
        self.info = info
        api.updateStream(stream: info) {
            handle(result: $0)
        }
    }

    private func rotateStreamKey() {
        api.rotateStreamKey {
            handle(result: $0) {
                if let streamKey = doinkStreamKey(url: stream.url) {
                    stream.url = stream.url.replacingOccurrences(of: streamKey, with: $0.streamKey)
                    model.reloadStreamIfEnabled(stream: stream)
                }
                reload()
            }
        }
    }

    var body: some View {
        Section {
            if let info {
                TextEditNavigationView(
                    title: String(localized: "Title"),
                    value: info.title,
                    onSubmit: { title in
                        update { $0.title = title }
                    }
                )
            } else {
                HStack {
                    Text("Title")
                    Spacer()
                    ProgressView()
                }
            }
        }
        Section {
            Toggle("Fallback", isOn: Binding(get: {
                info?.fallbackEnabled ?? false
            }, set: { enabled in
                update { $0.fallbackEnabled = enabled }
            }))
            Picker("Duration", selection: Binding(get: {
                info?.fallbackMinutes ?? fallbackMinutes[0]
            }, set: { minutes in
                update { $0.fallbackMinutes = minutes }
            })) {
                ForEach(fallbackMinutes, id: \.self) {
                    Text("\($0) min")
                }
            }
        } footer: {
            Text("Keeps your stream online for this long when you disconnect.")
        }
        .disabled(info == nil)
        DoinkTargetsView(api: api, targets: info?.targets ?? [], targetLimit: info?.targetLimit ?? 0) {
            handle(result: $0) { _ in
                reload()
            }
        }
        Section {
            TextButtonView("Rotate stream key") {
                presentingRotateStreamKey = true
            }
            .disabled(model.isLive)
            .confirmationDialog("", isPresented: $presentingRotateStreamKey) {
                Button("Rotate stream key", role: .destructive) {
                    rotateStreamKey()
                }
            }
        }
    }
}
