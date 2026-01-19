import SwiftUI

private enum ScheduleStreamState: Equatable {
    case idle
    case inProgress
    case succeeded
    case failed(String)
}

struct StreamYouTubeScheduleStream: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @State private var schedulingStreamState: ScheduleStreamState = .idle
    @State private var presenting: Bool = false

    private func scheduleStream() {
        schedulingStreamState = .inProgress
        model.getYouTubeAccesssToken(stream: stream) {
            guard let accessToken = $0 else {
                scheduleStreamFailed("Failed to get access token")
                return
            }
            let youTubeApi = YouTubeApi(accessToken: accessToken)
            youTubeApi.listLiveStreams {
                handleListLiveStreams(youTubeApi: youTubeApi, response: $0)
            }
        }
    }

    private func getLiveStream(liveStreams: YouTubeApiLiveStreamsListResponse) -> YouTubeApiLiveStream? {
        return liveStreams.items.first {
            let ingestionInfo = $0.cdn.ingestionInfo
            let url = "\(ingestionInfo.ingestionAddress)/\(ingestionInfo.streamName)"
            return url == stream.url
        } ?? liveStreams.items.first
    }

    private func handleListLiveStreams(
        youTubeApi: YouTubeApi,
        response: NetworkResponse<YouTubeApiLiveStreamsListResponse>
    ) {
        switch response {
        case let .success(liveStreams):
            guard let liveStream = getLiveStream(liveStreams: liveStreams) else {
                scheduleStreamFailed("No live stream found")
                return
            }
            youTubeApi.insertLiveBroadcast(title: stream.youTubeScheduleStreamTitle,
                                           visibility: stream.youTubeScheduleStreamVisibility)
            {
                handleInsertLiveBroadcastResponse(
                    youTubeApi: youTubeApi,
                    liveStream: liveStream,
                    response: $0
                )
            }
        case .authError:
            scheduleStreamFailed("Authentication failed")
        case .error:
            scheduleStreamFailed("Failed to list live streams")
        }
    }

    private func handleInsertLiveBroadcastResponse(youTubeApi: YouTubeApi,
                                                   liveStream: YouTubeApiLiveStream,
                                                   response: NetworkResponse<YouTubeApiLiveBroadcast>)
    {
        switch response {
        case let .success(liveBroadcast):
            youTubeApi.bindLiveBroadcast(boardcastId: liveBroadcast.id, streamId: liveStream.id) {
                if $0 {
                    stream.youTubeVideoId = liveBroadcast.id
                    model.youTubeVideoIdUpdated()
                    scheduleStreamSucceeded()
                } else {
                    scheduleStreamFailed("Failed to bind live stream to broadcast")
                }
            }
        case .authError:
            scheduleStreamFailed("Authentication failed")
        case .error:
            scheduleStreamFailed("Failed to create broadcast")
        }
    }

    private func scheduleStreamSucceeded() {
        schedulingStreamState = .succeeded
        idleSoon()
    }

    private func scheduleStreamFailed(_ message: String) {
        schedulingStreamState = .failed(message)
        idleSoon()
    }

    private func idleSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            schedulingStreamState = .idle
        }
    }

    var body: some View {
        Button {
            switch schedulingStreamState {
            case .idle:
                presenting = true
            default:
                break
            }
        } label: {
            HCenter {
                switch schedulingStreamState {
                case .idle:
                    Text("Schedule stream")
                case .inProgress:
                    ProgressView()
                case .succeeded:
                    Text("Stream scheduled")
                        .foregroundStyle(.green)
                case let .failed(message):
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .buttonStyle(.borderless)
        .disabled(stream.youTubeAuthState == nil)
        .sheet(isPresented: $presenting) {
            NavigationStack {
                Form {
                    Section {
                        TextField("", text: $stream.youTubeScheduleStreamTitle)
                    } header: {
                        Text("Title")
                    }
                    Section {
                        Picker("Visibility", selection: $stream.youTubeScheduleStreamVisibility) {
                            ForEach(YouTubeApiLiveBroadcaseVisibility.allCases, id: \.self) {
                                Text($0.toString())
                            }
                        }
                    }
                    Section {
                        CreateButtonView {
                            scheduleStream()
                            presenting = false
                        }
                    }
                }
                .navigationTitle("Schedule stream")
                .toolbar {
                    CloseToolbar(presenting: $presenting)
                }
            }
        }
    }
}

struct StreamYouTubeSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug
    @ObservedObject var stream: SettingsStream

    private func submitVideoId(value: String) {
        stream.youTubeVideoId = value
        if stream.enabled {
            model.youTubeVideoIdUpdated()
        }
    }

    private func submitHandle(value: String) {
        stream.youTubeHandle = value
    }

    var body: some View {
        Form {
            if debug.youTubeAuth {
                Section {
                    if stream.youTubeAuthState == nil {
                        TextButtonView("Login") {
                            model.youTubeSignIn(stream: stream)
                        }
                    } else {
                        TextButtonView("Logout") {
                            model.youTubeSignOut(stream: stream)
                        }
                    }
                }
                Section {
                    StreamYouTubeScheduleStream(model: model, stream: stream)
                } footer: {
                    Text("Schedule a stream before going live. It will use your first RTMP stream key.")
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel handle"),
                    value: String(stream.youTubeHandle),
                    onSubmit: submitHandle,
                    placeholder: "@erimo144"
                )
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: String(stream.youTubeVideoId),
                    onSubmit: submitVideoId,
                    placeholder: "FekKCUN5W8U"
                )
                TextButtonView("Fetch Video ID") {
                    Task { @MainActor in
                        do {
                            let videoId = try await fetchYouTubeVideoId(handle: stream.youTubeHandle)
                            submitVideoId(value: videoId)
                        } catch {
                            model.makeErrorToast(
                                title: String(localized: "Failed to fetch YouTube Video ID"),
                                subTitle: String(localized: "You must be live on YouTube for this to work.")
                            )
                        }
                    }
                }
            } footer: {
                Text("The Video ID unique for every live stream.")
            }
        }
        .navigationTitle("YouTube")
    }
}
