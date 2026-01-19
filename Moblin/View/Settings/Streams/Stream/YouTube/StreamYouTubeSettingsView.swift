import SwiftUI

private enum ScheduleStreamState: Equatable {
    case idle
    case inProgress
    case succeeded
    case failed(String)
}

private struct UpcomingStreamView: View {
    @Binding var upcomingStream: YouTubeApiLiveBroadcast

    var body: some View {
        if let scheduledStartTime = upcomingStream.snippet.scheduledStartTime,
           let date = ISO8601DateFormatter().date(from: scheduledStartTime),
           let thumbnailUrl = URL(string: upcomingStream.snippet.thumbnails.default.url)
        {
            HStack {
                CacheAsyncImage(url: thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image("AppIconNoBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading) {
                    Text(upcomingStream.snippet.title)
                    Text(date.formatted())
                        .font(.caption)
                }
                Spacer()
            }
        }
    }
}

struct StreamYouTubeScheduleStreamView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @State private var schedulingStreamState: ScheduleStreamState = .idle
    @State private var presenting: Bool = false
    @State private var upcomingStreams: [YouTubeApiLiveBroadcast] = []

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
                    loadUpcomingStreams()
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
    }

    private func scheduleStreamFailed(_ message: String) {
        schedulingStreamState = .failed(message)
    }

    private func loadUpcomingStreams() {
        model.getYouTubeAccesssToken(stream: stream) {
            guard let accessToken = $0 else {
                return
            }
            YouTubeApi(accessToken: accessToken).listLiveBroadcasts {
                switch $0 {
                case let .success(response):
                    upcomingStreams = response.items
                case .authError:
                    break
                case .error:
                    break
                }
            }
        }
    }

    var body: some View {
        TextButtonView("Schedule stream") {
            presenting = true
        }
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
                        switch schedulingStreamState {
                        case .idle:
                            Button {
                                scheduleStream()
                            } label: {
                                HCenter {
                                    Text("Schedule stream")
                                }
                            }
                        case .inProgress:
                            HCenter {
                                ProgressView()
                            }
                        case .succeeded:
                            HCenter {
                                Text("Stream scheduled")
                            }
                        case let .failed(message):
                            HCenter {
                                Text(message)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Section {
                        ForEach($upcomingStreams) { $upcomingStream in
                            UpcomingStreamView(upcomingStream: $upcomingStream)
                        }
                    } header: {
                        Text("Upcoming streams")
                    }
                }
                .navigationTitle("Schedule stream")
                .toolbar {
                    CloseToolbar(presenting: $presenting)
                }
            }
            .onAppear {
                schedulingStreamState = .idle
                loadUpcomingStreams()
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
                    StreamYouTubeScheduleStreamView(model: model, stream: stream)
                } footer: {
                    Text("Schedule a stream before going live.")
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
