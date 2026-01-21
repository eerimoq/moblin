import SwiftUI

private enum ScheduleStreamState: Equatable {
    case idle
    case inProgress
    case succeeded
    case failed(String)
}

private struct StreamDescriptionView: View {
    let stream: YouTubeApiLiveBroadcast
    let thumbnailUrl: URL
    let startTime: Date

    var body: some View {
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
            Text(stream.snippet.title)
            Text(startTime.formatted())
                .font(.caption)
            Text(stream.status.privacyStatus.capitalized)
                .font(.caption)
        }
    }
}

private struct YouTubeStreamView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    let youTubeStream: YouTubeApiLiveBroadcast
    let onDeleted: (String) -> Void
    @State private var deleting: Bool = false

    private func delete() {
        deleting = true
        model.getYouTubeApi(stream: stream) { youTubeApi in
            guard let youTubeApi else {
                deleting = false
                return
            }
            youTubeApi.deleteLiveBroadcast(id: youTubeStream.id) {
                switch $0 {
                case .success:
                    onDeleted(youTubeStream.id)
                default:
                    break
                }
                deleting = false
            }
        }
    }

    var body: some View {
        if let scheduledStartTime = youTubeStream.snippet.scheduledStartTime,
           let date = ISO8601DateFormatter().date(from: scheduledStartTime),
           let thumbnailUrl = URL(string: youTubeStream.snippet.thumbnails.default.url)
        {
            HStack {
                StreamDescriptionView(stream: youTubeStream, thumbnailUrl: thumbnailUrl, startTime: date)
                Spacer()
                HCenter {
                    if deleting {
                        ProgressView()
                    } else {
                        Button {
                            delete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.title)
                                .tint(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(width: 50)
            }
            .padding([.trailing], 5)
        }
    }
}

private struct StreamsView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    let title: LocalizedStringKey
    @Binding var streams: [YouTubeApiLiveBroadcast]
    @Binding var loadError: String?

    var body: some View {
        Section {
            ForEach(streams) {
                YouTubeStreamView(model: model, stream: stream, youTubeStream: $0) { id in
                    streams.removeAll { $0.id == id }
                }
            }
            if streams.isEmpty {
                HCenter {
                    if let loadError {
                        Text(loadError)
                    } else {
                        Text("None")
                    }
                }
            }
        } header: {
            Text(title)
        }
    }
}

private struct ScheduleStreamView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @Binding var schedulingStreamState: ScheduleStreamState
    let loadStreams: () -> Void

    private func scheduleStream() {
        schedulingStreamState = .inProgress
        model.getYouTubeApi(stream: stream) { youTubeApi in
            guard let youTubeApi else {
                scheduleStreamFailed("Failed to get access token")
                return
            }
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
                    loadStreams()
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
        Section {
            TextField("Title", text: $stream.youTubeScheduleStreamTitle)
            Picker("Visibility", selection: $stream.youTubeScheduleStreamVisibility) {
                ForEach(YouTubeApiLiveBroadcaseVisibility.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            switch schedulingStreamState {
            case .idle:
                TextButtonView("Create") {
                    scheduleStream()
                }
                .disabled(stream.youTubeScheduleStreamTitle.isEmpty)
            case .inProgress:
                HCenter {
                    Text("Creating...")
                }
            case .succeeded:
                HCenter {
                    Text("Created")
                }
            case let .failed(message):
                HCenter {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Schedule")
        }
    }
}

struct StreamYouTubeScheduleStreamView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @State private var schedulingStreamState: ScheduleStreamState = .idle
    @State private var presenting: Bool = false
    @State private var liveStreams: [YouTubeApiLiveBroadcast] = []
    @State private var liveStreamsLoadError: String?
    @State private var upcomingStreams: [YouTubeApiLiveBroadcast] = []
    @State private var upcomingStreamsLoadError: String?

    private func loadStreams() {
        loadActiveStreams()
        loadUpcomingStreams()
    }

    private func loadActiveStreams() {
        liveStreamsLoadError = nil
        model.getYouTubeApi(stream: stream) { youTubeApi in
            youTubeApi?.listLiveBroadcasts(status: "active") {
                switch $0 {
                case let .success(response):
                    liveStreams = response.items
                case .authError:
                    liveStreamsLoadError = "Error"
                case .error:
                    liveStreamsLoadError = "Error"
                }
            }
        }
    }

    private func loadUpcomingStreams() {
        upcomingStreamsLoadError = nil
        model.getYouTubeApi(stream: stream) { youTubeApi in
            youTubeApi?.listLiveBroadcasts(status: "upcoming") {
                switch $0 {
                case let .success(response):
                    upcomingStreams = response.items.filter { $0.snippet.scheduledStartTime != nil }
                case .authError:
                    upcomingStreamsLoadError = "Error"
                case .error:
                    upcomingStreamsLoadError = "Error"
                }
            }
        }
    }

    var body: some View {
        TextButtonView("Manage streams") {
            presenting = true
        }
        .disabled(stream.youTubeAuthState == nil)
        .sheet(isPresented: $presenting) {
            NavigationStack {
                Form {
                    ScheduleStreamView(model: model,
                                       stream: stream,
                                       schedulingStreamState: $schedulingStreamState,
                                       loadStreams: loadStreams)
                    StreamsView(model: model,
                                stream: stream,
                                title: "Live",
                                streams: $liveStreams,
                                loadError: $liveStreamsLoadError)
                    StreamsView(model: model,
                                stream: stream,
                                title: "Upcoming",
                                streams: $upcomingStreams,
                                loadError: $upcomingStreamsLoadError)
                }
                .navigationTitle("Manage streams")
                .toolbar {
                    CloseToolbar(presenting: $presenting)
                }
            }
            .onAppear {
                schedulingStreamState = .idle
                loadStreams()
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
