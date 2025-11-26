import SwiftUI

private struct ReplayPreview: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    private func width() -> Double {
        if model.stream.portrait {
            return 200
        } else {
            return 300
        }
    }

    var body: some View {
        if !replay.isPlaying, let image = replay.previewImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width())
                .cornerRadius(7)
                .onTapGesture {
                    replay.previewImage = nil
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
        SegmentedPicker(SettingsReplaySpeed.allCases, selectedItem: $replay.speed) {
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

private struct ReplayControls: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider
    @ObservedObject var orientation: Orientation

    private func portrait() -> some View {
        VStack(alignment: .trailing) {
            HStack {
                ReplayControlsInterval(replay: replay)
            }
            .padding(4)
            .padding([.trailing], 4)
            .font(.title)
            .frame(height: 45)
            .background(backgroundColor)
            .cornerRadius(5)
            HStack {
                ReplayControlsSpeedPicker(replay: replay)
                ReplayControlsPlayPauseButton(replay: replay)
                Divider().overlay(.white)
                ReplayControlsSaveButton(replay: replay)
            }
            .padding(4)
            .padding([.leading, .trailing], 4)
            .font(.title)
            .frame(height: 45)
            .background(backgroundColor)
            .cornerRadius(5)
        }
    }

    private func landscape() -> some View {
        HStack {
            ReplayControlsInterval(replay: replay)
            ReplayControlsSpeedPicker(replay: replay)
            ReplayControlsPlayPauseButton(replay: replay)
            Divider().overlay(.white)
            ReplayControlsSaveButton(replay: replay)
        }
        .padding(4)
        .padding([.trailing], 4)
        .font(.title)
        .frame(height: 45)
        .background(backgroundColor)
        .cornerRadius(5)
    }

    var body: some View {
        if orientation.isPortrait {
            portrait()
        } else {
            landscape()
        }
    }
}

private struct ReplayHistoryItem: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider
    let video: ReplaySettings
    @State var image: UIImage?

    private func height() -> Double {
        if model.stream.portrait {
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
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider

    private func height() -> Double {
        if model.stream.portrait {
            return 120
        } else {
            return 70
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                if model.replaysStorage.database.replays.isEmpty {
                    Text("No replays saved")
                        .padding([.leading], 30)
                        .foregroundStyle(.white)
                }
                ForEach(model.replaysStorage.database.replays) {
                    ReplayHistoryItem(replay: replay, video: $0)
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
    @ObservedObject var replay: ReplayProvider
    let orientation: Orientation

    var body: some View {
        VStack(alignment: .trailing) {
            ReplayPreview(replay: replay)
            ReplayControls(replay: replay, orientation: orientation)
            ReplayHistory(replay: replay)
        }
    }
}
