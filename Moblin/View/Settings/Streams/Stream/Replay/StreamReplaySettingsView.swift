import SwiftUI
import UniformTypeIdentifiers

private struct VideoPickerView: UIViewControllerRepresentable {
    let model: Model

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.movie],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

private let ffmpegCommand = """
ffmpeg -c:v libvpx-vp9 -i my-stinger.webm -c:v hevc_videotoolbox -b:v 15M -allow_sw 1 \
-alpha_quality 1 -vtag hvc1 my-stinger.mov
"""

private struct HelpView: View {
    @Binding var presentingHelp: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Text("NOTE: Only works on Mac as `hevc_videotoolbox` uses Apple’s encoder.")
                        Text("")
                        HStack {
                            Text("`\(ffmpegCommand)`")
                            Button {
                                UIPasteboard.general.string = ffmpegCommand
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("How to convert `.webm` (VP9) to `.mov` (HEVC) with alpha channel")
                }
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentingHelp = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

private struct StingerView: View {
    let model: Model
    let title: LocalizedStringKey
    @Binding var stinger: SettingsStreamReplayStinger
    @State private var showPicker = false
    @State private var presentingHelp: Bool = false

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
                        VideoPickerView(model: model)
                    }
                } footer: {
                    Text("Use the HEVC/H.265 codec with alpha channel for transparent background.")
                }
                Section {
                    TextButtonView("Help") {
                        presentingHelp = true
                    }
                    .sheet(isPresented: $presentingHelp) {
                        HelpView(presentingHelp: $presentingHelp)
                    }
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
