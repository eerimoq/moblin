import CoreMedia
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
ffmpeg -c:v libvpx-vp9 -i input.webm -c:v hevc_videotoolbox -alpha_quality 1 -vtag hvc1 output.mov
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
                        CommandCopyView(command: ffmpegCommand)
                    }
                } header: {
                    Text("How to convert `.webm` (VP9) to `.mov` (HEVC) with alpha channel")
                }
            }
            .navigationTitle("Help")
            .toolbar {
                CloseToolbar(presenting: $presentingHelp)
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
                GrayTextView(text: stinger.name)
            }
        }
    }
}

private struct LayoutView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var replay: SettingsStreamReplay

    private func dimensions() -> CMVideoDimensions {
        model.stream.resolution.dimensions(portrait: model.stream.portrait)
    }

    private func horizontalIncrement() -> Double {
        100 / Double(dimensions().width)
    }

    private func verticalIncrement() -> Double {
        100 / Double(dimensions().height)
    }

    private func setXBasedOnYIfLocked() {
        guard replay.layout.positioningLock else {
            return
        }
        replay.layout.x = replay.layout.y * horizontalIncrement() / verticalIncrement()
        replay.layout.xString = String(replay.layout.x)
    }

    private func setYBasedOnXIfLocked() {
        guard replay.layout.positioningLock else {
            return
        }
        replay.layout.y = replay.layout.x * verticalIncrement() / horizontalIncrement()
        replay.layout.yString = String(replay.layout.y)
    }

    private func generalAndAlignmentPicker() -> some View {
        HStack {
            HStack {
                SaveLoadLayoutView(layout: $replay.layout)
                Spacer()
            }
            Divider()
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    AlignmentOptionView(layout: $replay.layout, alignment: .topLeft)
                    AlignmentOptionView(layout: $replay.layout, alignment: .topCenter)
                    AlignmentOptionView(layout: $replay.layout, alignment: .topRight)
                }
                HStack(spacing: 3) {
                    AlignmentOptionView(layout: $replay.layout, alignment: .leftCenter)
                    AlignmentOptionView(layout: $replay.layout, alignment: .center)
                    AlignmentOptionView(layout: $replay.layout, alignment: .rightCenter)
                }
                HStack(spacing: 3) {
                    AlignmentOptionView(layout: $replay.layout, alignment: .bottomLeft)
                    AlignmentOptionView(layout: $replay.layout, alignment: .bottomCenter)
                    AlignmentOptionView(layout: $replay.layout, alignment: .bottomRight)
                }
            }
        }
    }

    var body: some View {
        Section {
            generalAndAlignmentPicker()
            if !replay.layout.alignment.isHorizontalCenter(),
               !replay.layout.alignment.isVerticalCenter()
            {
                HStack(alignment: .center) {
                    VStack {
                        PositionEditView(
                            number: $replay.layout.x,
                            value: $replay.layout.xString,
                            onSubmit: { setYBasedOnXIfLocked() },
                            numericInput: $database.sceneNumericInput,
                            incrementImageName: "arrow.forward.circle",
                            decrementImageName: "arrow.backward.circle",
                            mirror: replay.layout.alignment.mirrorPositionHorizontally(),
                            increment: horizontalIncrement()
                        )
                        .padding(.bottom, 10)
                        PositionEditView(
                            number: $replay.layout.y,
                            value: $replay.layout.yString,
                            onSubmit: { setXBasedOnYIfLocked() },
                            numericInput: $database.sceneNumericInput,
                            incrementImageName: "arrow.down.circle",
                            decrementImageName: "arrow.up.circle",
                            mirror: replay.layout.alignment.mirrorPositionVertically(),
                            increment: verticalIncrement()
                        )
                    }
                    Button {
                        replay.layout.positioningLock.toggle()
                        setYBasedOnXIfLocked()
                    } label: {
                        Image(systemName: replay.layout.positioningLock ? "lock" : "lock.open")
                            .font(.title)
                            .frame(width: 35)
                    }
                    .buttonStyle(.borderless)
                }
            } else if !replay.layout.alignment.isHorizontalCenter() {
                PositionEditView(
                    number: $replay.layout.x,
                    value: $replay.layout.xString,
                    onSubmit: {},
                    numericInput: $database.sceneNumericInput,
                    incrementImageName: "arrow.forward.circle",
                    decrementImageName: "arrow.backward.circle",
                    mirror: replay.layout.alignment.mirrorPositionHorizontally(),
                    increment: horizontalIncrement()
                )
            } else if !replay.layout.alignment.isVerticalCenter() {
                PositionEditView(
                    number: $replay.layout.y,
                    value: $replay.layout.yString,
                    onSubmit: {},
                    numericInput: $database.sceneNumericInput,
                    incrementImageName: "arrow.down.circle",
                    decrementImageName: "arrow.up.circle",
                    mirror: replay.layout.alignment.mirrorPositionVertically(),
                    increment: verticalIncrement()
                )
            }
            SizeEditView(
                number: $replay.layout.size,
                value: $replay.layout.sizeString,
                onSubmit: {},
                numericInput: $database.sceneNumericInput
            )
            Toggle("Numeric input", isOn: $database.sceneNumericInput)
        } header: {
            Text("Layout")
        }
        .onChange(of: replay.layout) { _ in
            model.replayEffect?.setLayout(layout: replay.layout)
        }
    }
}

struct StreamReplaySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
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
            }
            if database.showAllSettings {
                LayoutView(model: model, database: database, replay: replay)
                Section {
                    Picker("Transition", selection: $replay.transitionType) {
                        ForEach(SettingsStreamReplayTransitionType.allCases, id: \.self) { transitionType in
                            Text(transitionType.toString())
                        }
                    }
                    switch replay.transitionType {
                    case .fade:
                        EmptyView()
                    case .stingers:
                        StingerView(model: model, title: "In video", stinger: $replay.inStinger)
                        StingerView(model: model, title: "Out video", stinger: $replay.outStinger)
                    case .none:
                        EmptyView()
                    }
                }
                Section {
                    Picker("Post trigger delay", selection: $replay.postTriggerDelay) {
                        ForEach([2, 3, 4, 5], id: \.self) { delay in
                            Text("\(delay) s")
                        }
                    }
                } footer: {
                    Text("Seconds to record after the Instant replay/Save replay button is pressed.")
                }
            }
        }
        .navigationTitle("Replay")
    }
}
