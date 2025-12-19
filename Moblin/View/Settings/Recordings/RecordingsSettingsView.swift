import SwiftUI

private let ffmpegCommand = "ffmpeg -i input.mp4 -c copy output.mp4"

private let ffmpegConstantFrameRateCommand = """
ffmpeg -i input.mp4 -vf "fps=60" -c:v hevc_videotoolbox -c:a copy output.mp4
"""

private struct RecordingsLocationView: View {
    let model: Model
    let text: Text
    let path: URL

    private func makeSharedUrl(path: URL) -> URL? {
        guard let sharedUrl = URL(string: "shareddocuments://\(path.path())") else {
            return nil
        }
        if UIApplication.shared.canOpenURL(sharedUrl) {
            return sharedUrl
        } else {
            return nil
        }
    }

    private func openInFilesApp(sharedUrl: URL) {
        UIApplication.shared.open(sharedUrl)
    }

    private func copyPathToClipboard(path: URL) {
        UIPasteboard.general.string = path.path()
        let subTitle: String?
        if isMac() {
            subTitle = String(localized: "Open it in Finder app → Go → Go to Folder...")
        } else {
            subTitle = nil
        }
        model.makeToast(title: String(localized: "Directory copied to clipboard"), subTitle: subTitle)
    }

    var body: some View {
        Section {
            HStack {
                text
                Spacer()
                if let sharedUrl = makeSharedUrl(path: path) {
                    Button {
                        openInFilesApp(sharedUrl: sharedUrl)
                    } label: {
                        Image(systemName: "arrow.turn.up.right")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                } else {
                    Button {
                        copyPathToClipboard(path: path)
                    } label: {
                        Image(systemName: "document.on.document")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
    }
}

private struct HelpView: View {
    @Binding var presentingHelp: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("""
                    Recordings are saved as variable frame rate (VFR) fragmented MP4 to be resilient \
                    against crashes and other unexpected errors. Converting them to constant frame \
                    rate (CFR) standard MP4 can improve compatibility with video players and video \
                    editing software.
                    """)
                }
                Section {
                    CommandCopyView(command: ffmpegCommand)
                } header: {
                    Text("How to convert a recording to standard MP4")
                }
                Section {
                    VStack(alignment: .leading) {
                        CommandCopyView(command: ffmpegConstantFrameRateCommand)
                        Text("")
                        Text("""
                        Replace `hevc_videotoolbox` with your preferred encoder, typically a hardware \
                        encoder for faster conversion.
                        """)
                    }
                } header: {
                    Text("How to convert a recording to constant frame rate (CFR) standard MP4")
                }
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ToolbarCloseButtonView(presenting: $presentingHelp)
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    let model: Model
    @State private var presentingHelp: Bool = false

    var body: some View {
        Form {
            RecordingsLocationView(model: model,
                                   text: Text("Default recordings directory"),
                                   path: model.recordingsStorage.defaultStorageDirectory())
            if let path = model.stream.recording.recordingPath {
                if let path = makeRecordingPath(recordingPath: path) {
                    RecordingsLocationView(model: model,
                                           text: Text("Current recordings directory"),
                                           path: path)
                } else {
                    Text("Current recordings directory unavailable")
                }
            }
            RecordingsLocationView(model: model,
                                   text: Text("Replays directory"),
                                   path: model.replaysStorage.defaultStorageDirectory())
            Section {
                TextButtonView("Help") {
                    presentingHelp = true
                }
                .sheet(isPresented: $presentingHelp) {
                    HelpView(presentingHelp: $presentingHelp)
                }
            }
        }
        .navigationTitle("Recordings")
    }
}
