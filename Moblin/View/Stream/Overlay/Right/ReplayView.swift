import SwiftUI

private struct ReplayPreview: View {
    let model: Model
    @ObservedObject var orientation: Orientation
    @ObservedObject var replay: ReplayProvider

    private func width() -> Double {
        if orientation.isPortrait {
            return 200
        } else {
            return 300
        }
    }

    var body: some View {
        if !replay.isPlaying, let image = replay.previewImage {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: width())
                    .cornerRadius(7)
                    .onTapGesture {
                        replay.previewImage = nil
                    }
                    .overlay(
                        Button {
                            model.deleteSelectedReplay()
                            replay.selectedId = nil
                            replay.previewImage = nil
                        } label: {
                            if #available(iOS 26, *) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .frame(width: 12, height: 12)
                                    .padding()
                                    .glassEffect()
                                    .padding(2)
                            } else {
                                Image(systemName: "trash")
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(.gray)
                                    )
                                    .foregroundStyle(.red)
                                    .padding(7)
                            }
                        },
                        alignment: .topLeading
                    )
            }
        }
    }
}

private struct ReplayControlsInterval: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    var body: some View {
        Slider(value: $replay.startFromEnd,
               in: 0 ... SettingsReplay.stop,
               step: 0.1,
               onEditingChanged: { _ in
               })
               .frame(width: 250)
               .onChange(of: replay.startFromEnd) {
                   model.setReplayPosition(start: SettingsReplay.stop - $0)
               }
               .rotationEffect(.degrees(180))
        Text("\(Int(replay.startFromEnd))s")
            .frame(width: 35)
            .font(.body)
            .foregroundStyle(.white)
    }
}

private struct ReplayControlsSpeedPicker: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    var body: some View {
        SegmentedHPicker(items: SettingsReplaySpeed.allCases, selectedItem: $replay.speed) {
            Text($0.rawValue)
                .font(.subheadline)
                .frame(height: 35)
        }
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
        .frame(width: 90)
        .onChange(of: replay.speed) { _ in
            model.replaySpeedChanged()
        }
        .foregroundStyle(.white)
    }
}

private struct ReplayControlsPlayPauseButton: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    private func playStopImage() -> String {
        if replay.isPlaying {
            return "stop"
        } else {
            return "play"
        }
    }

    var body: some View {
        Button {
            replay.isPlaying.toggle()
            if replay.isPlaying {
                if !model.replayPlay() {
                    replay.isPlaying = false
                }
            } else {
                model.replayCancel()
            }
        } label: {
            let image = Image(systemName: playStopImage())
                .frame(width: 30)
            if replay.selectedId != nil {
                image.foregroundStyle(.white)
            } else {
                image
            }
        }
        .disabled(replay.selectedId == nil)
    }
}

private struct ReplayControlsSaveButton: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    var body: some View {
        if replay.isSaving {
            ProgressView()
                .frame(width: 30)
                .tint(.white)
        } else {
            Button {
                if model.stream.replay.enabled {
                    _ = model.saveReplay()
                } else {
                    model.makeReplayIsNotEnabledToast()
                }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 30)
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct ControlRowView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            content()
        }
        .padding(4)
        .padding([.trailing], 4)
        .font(.title)
        .frame(height: 45)
        .background(backgroundColor)
        .cornerRadius(5)
    }
}

private struct ReplayControls: View {
    @ObservedObject var replay: ReplayProvider
    @ObservedObject var orientation: Orientation

    var body: some View {
        if orientation.isPortrait {
            VStack(alignment: .trailing) {
                ControlRowView {
                    ReplayControlsInterval(replay: replay)
                }
                ControlRowView {
                    ReplayControlsSpeedPicker(replay: replay)
                    ReplayControlsPlayPauseButton(replay: replay)
                    Divider()
                        .overlay(.white)
                    ReplayControlsSaveButton(replay: replay)
                }
            }
        } else {
            ControlRowView {
                ReplayControlsInterval(replay: replay)
                ReplayControlsSpeedPicker(replay: replay)
                ReplayControlsPlayPauseButton(replay: replay)
                Divider()
                    .overlay(.white)
                ReplayControlsSaveButton(replay: replay)
            }
        }
    }
}

private struct ReplayHistoryItem: View {
    let model: Model
    @ObservedObject var orientation: Orientation
    @ObservedObject var replay: ReplayProvider
    let video: ReplaySettings
    @State var image: UIImage?
    @State var presentingMenu: Bool = false

    private func height() -> Double {
        if orientation.isPortrait {
            return 118
        } else {
            return 68
        }
    }

    var body: some View {
        VStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .frame(height: height())
                    .onTapGesture {
                        model.loadReplay(video: video)
                    }
                    .overlay {
                        if video.id == replay.selectedId {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(.white, lineWidth: 2)
                        }
                    }
            } else {
                Image(systemName: "camera")
            }
        }
        .onAppear {
            createThumbnail(path: video.url(), offset: video.thumbnailOffset()) { image in
                self.image = image
            }
        }
    }
}

private struct ReplayHistory: View {
    let model: Model
    @ObservedObject var orientation: Orientation
    @ObservedObject var replayDatabase: ReplaysDatabase
    @ObservedObject var replay: ReplayProvider

    private func height() -> Double {
        if orientation.isPortrait {
            return 120
        } else {
            return 70
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                if replayDatabase.replays.isEmpty {
                    Text("No replays saved")
                        .padding([.leading], 30)
                        .foregroundStyle(.white)
                }
                ForEach(replayDatabase.replays) {
                    ReplayHistoryItem(model: model, orientation: orientation, replay: replay, video: $0)
                }
            }
            .frame(height: height())
        }
        .scrollIndicators(.hidden)
        .padding(4)
        .background(backgroundColor)
        .cornerRadius(5)
    }
}

struct StreamOverlayRightReplayView: View {
    let model: Model
    @ObservedObject var replay: ReplayProvider
    let orientation: Orientation

    var body: some View {
        VStack(alignment: .trailing) {
            ReplayPreview(model: model, orientation: orientation, replay: replay)
            ReplayControls(replay: replay, orientation: orientation)
            ReplayHistory(model: model,
                          orientation: orientation,
                          replayDatabase: model.replaysStorage.database,
                          replay: replay)
        }
    }
}
