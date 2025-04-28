import SwiftUI

private struct ReplayPreview: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if !model.replayPlaying, let image = model.replayImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300)
                .cornerRadius(7)
                .onTapGesture {
                    model.replayImage = nil
                }
        }
    }
}

private struct ReplayControlsInterval: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Slider(value: $model.replayStartFromEnd,
               in: 0 ... 30,
               step: 0.1,
               onEditingChanged: { _ in
               })
               .frame(width: 250)
               .onChange(of: model.replayStartFromEnd) {
                   model.setReplayPosition(start: 30 - $0)
               }
               .rotationEffect(.degrees(180))
               .disabled(model.selectedReplayId == nil)
        Text("\(Int(model.replayStartFromEnd))s")
            .frame(width: 30)
            .font(.body)
            .foregroundColor(.white)
    }
}

private struct ReplayControlsSpeedPicker: View {
    @EnvironmentObject var model: Model

    var body: some View {
        SegmentedPicker(SettingsReplaySpeed.allCases, selectedItem: $model.replaySpeed) {
            Text($0.rawValue)
                .font(.subheadline)
                .frame(width: 30, height: 35)
        }
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
        .frame(width: 90)
        .onChange(of: model.replaySpeed) { _ in
            model.replaySpeedChanged()
        }
        .foregroundColor(.white)
    }
}

private struct ReplayControlsPlayPauseButton: View {
    @EnvironmentObject var model: Model

    private func playStopImage() -> String {
        if model.replayPlaying {
            return "stop"
        } else {
            return "play"
        }
    }

    var body: some View {
        Button {
            model.replayPlaying.toggle()
            if model.replayPlaying {
                if !model.replayPlay() {
                    model.replayPlaying = false
                }
            } else {
                model.replayCancel()
            }
        } label: {
            let image = Image(systemName: playStopImage())
                .frame(width: 30)
            if model.selectedReplayId != nil {
                image.foregroundColor(.white)
            } else {
                image
            }
        }
        .disabled(model.selectedReplayId == nil)
    }
}

private struct ReplayControlsSaveButton: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if model.replayIsSaving {
            ProgressView()
                .frame(width: 30)
                .tint(.white)
        } else {
            Button {
                if model.isRecording {
                    model.saveReplay()
                } else {
                    model.makeToast(title: String(localized: "Can only save replay when recording"))
                }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 30)
                    .foregroundColor(.white)
            }
        }
    }
}

private struct ReplayControls: View {
    @EnvironmentObject var model: Model

    private func playStopImage() -> String {
        if model.replayPlaying {
            return "stop"
        } else {
            return "play"
        }
    }

    var body: some View {
        HStack {
            ReplayControlsInterval()
            ReplayControlsSpeedPicker()
            ReplayControlsPlayPauseButton()
            Divider()
            ReplayControlsSaveButton()
        }
        .padding(4)
        .font(.title)
        .frame(height: 45)
        .background(backgroundColor)
        .cornerRadius(5)
    }
}

private struct ReplayHistoryItem: View {
    @EnvironmentObject var model: Model
    var replay: ReplaySettings

    var body: some View {
        if let image = createThumbnail(path: replay.url(), offset: replay.thumbnailOffset()) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(5)
                .frame(height: 68)
                .onTapGesture {
                    model.loadReplay(video: replay)
                }
                .overlay {
                    if replay.id == model.selectedReplayId {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.white, lineWidth: 2)
                    }
                }
        }
    }
}

private struct ReplayHistory: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                if model.replaysStorage.database.replays.isEmpty {
                    Image(systemName: "photo.artframe")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(5)
                        .frame(height: 68)
                }
                ForEach(model.replaysStorage.database.replays) { replay in
                    ReplayHistoryItem(replay: replay)
                }
            }
            .frame(height: 70)
        }
        .scrollIndicators(.hidden)
        .padding(4)
        .background(backgroundColor)
        .cornerRadius(5)
    }
}

struct StreamOverlayRightReplayView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing) {
            ReplayPreview()
            ReplayControls()
            ReplayHistory()
        }
    }
}
