import SwiftUI
import UniformTypeIdentifiers

private struct VideoPickerView: UIViewControllerRepresentable {
    let model: Model
    let type: UTType

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [type],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

private struct StingerView: View {
    let model: Model
    let title: LocalizedStringKey
    @Binding var stinger: SettingsStreamReplayStinger
    @State var showPicker = false

    private func onUrl(url: URL) {
        stinger.name = url.lastPathComponent
        if let filename = stinger.makeFilename() {
            model.replayTransitionsStorage.remove(filename: filename)
            model.replayTransitionsStorage.add(filename: filename, url: url)
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Button {
                        showPicker = true
                        model.onDocumentPickerUrl = onUrl
                    } label: {
                        HCenter {
                            if stinger.name.isEmpty {
                                Text("Select video")
                            } else {
                                Text(stinger.name)
                            }
                        }
                    }
                    .sheet(isPresented: $showPicker) {
                        VideoPickerView(model: model, type: .movie)
                    }
                } footer: {
                    Text("Use the HEVC/H.265 codec with alpha channel for transparent background.")
                }
            }
            .navigationTitle(title)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(stinger.name)
                    .foregroundStyle(.gray)
            }
        }
    }
}

struct StreamReplaySettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream
    @ObservedObject var replay: SettingsStreamReplay

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $replay.enabled)
                    .onChange(of: replay.enabled) { _ in
                        if stream.enabled {
                            model.streamReplayEnabledUpdated()
                        }
                    }
                if model.database.showAllSettings {
                    Picker("Transition", selection: $replay.transitionType) {
                        ForEach(SettingsStreamReplayTransitionType.allCases, id: \.self) { transitionType in
                            Text(transitionType.toString())
                        }
                    }
                }
            }
            if model.database.showAllSettings {
                switch replay.transitionType {
                case .fade:
                    EmptyView()
                case .stingers:
                    Section {
                        StingerView(model: model, title: "In video", stinger: $replay.inStinger)
                        StingerView(model: model, title: "Out video", stinger: $replay.outStinger)
                    } header: {
                        Text("Stingers")
                    }
                case .none:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Replay")
    }
}
