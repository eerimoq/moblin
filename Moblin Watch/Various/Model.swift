import Collections
import Foundation
import HealthKit
import SwiftUI
import WatchConnectivity

// Remote control assistant polls status every 5 seconds.
private let previewTimeout = Duration.seconds(6)

struct ChatPostSegment: Identifiable {
    var id = UUID()
    var text: String?
    var url: URL?
}

enum ChatPostKind {
    case normal
    case redLine
    case info
}

enum ChatPostHighlightKind {
    case redemption
    case other

    static func fromWatchProtocol(kind: WatchProtocolChatHighlightKind) -> ChatPostHighlightKind {
        switch kind {
        case .redemption:
            return .redemption
        case .other:
            return .other
        }
    }
}

struct ChatPostHighlight {
    let kind: ChatPostHighlightKind
    let color: Color
    let image: String
    let title: String

    static func fromWatchProtocol(highlight: WatchProtocolChatHighlight) -> ChatPostHighlight {
        return ChatPostHighlight(
            kind: ChatPostHighlightKind.fromWatchProtocol(kind: highlight.kind),
            color: highlight.color.color(),
            image: highlight.image,
            title: highlight.title
        )
    }
}

struct ChatPost: Identifiable {
    var id: Int
    var kind: ChatPostKind
    var user: String
    var userColor: Color
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var highlight: ChatPostHighlight?

    func isRedemption() -> Bool {
        return highlight?.kind == .redemption
    }
}

class Model: NSObject, ObservableObject {
    @Published var chatPosts = Deque<ChatPost>()
    @Published var speedAndTotal = noValue
    private var latestSpeedAndTotalTime = ContinuousClock.now
    @Published var recordingLength = noValue
    private var latestRecordingLengthTime = ContinuousClock.now
    @Published var audioLevel: Float = defaultAudioLevel
    private var latestAudioLevelTime = ContinuousClock.now
    @Published var preview: UIImage?
    @Published var showPreviewDisconnected = true
    private var latestPreviewTime = ContinuousClock.now
    var settings = WatchSettings()
    private var latestChatMessageTime = ContinuousClock.now
    private var numberOfNormalPostsInChat = 0
    private var nextExpectedWatchChatPostId = 1
    private var nextNonNormalChatLineId = -1
    private var logId = 1
    var numberOfMessagesReceived = 0
    @Published var isLive = false
    @Published var isRecording = false
    @Published var isMuted = false
    @Published var thermalState = ProcessInfo.ThermalState.nominal
    private var latestThermalStateTime = ContinuousClock.now
    @Published var zoomX = 0.0
    @Published var isZooming = false
    @Published var zoomPresets: [WatchProtocolZoomPreset] = []
    @Published var zoomPresetId: UUID = .init()
    @Published var zoomPresetIdPicker: UUID?
    @Published var scenes: [WatchProtocolScene] = []
    @Published var sceneId: UUID = .init()
    @Published var sceneIdPicker: UUID = .init()
    @Published var verboseStatuses = false
    private var healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    @Published var workoutType = noValue

    func setup() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        setupPeriodicTimers()
    }

    private func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.updatePreview()
            self.keepAlive()
        })
    }

    private func updatePreview() {
        let deadline = ContinuousClock.now - previewTimeout
        if latestPreviewTime < deadline, !showPreviewDisconnected {
            showPreviewDisconnected = true
        }
        if latestSpeedAndTotalTime < deadline, speedAndTotal != noValue {
            speedAndTotal = noValue
        }
        if latestRecordingLengthTime < deadline, recordingLength != noValue {
            recordingLength = noValue
        }
        if latestAudioLevelTime < deadline, audioLevel != defaultAudioLevel {
            audioLevel = defaultAudioLevel
        }
        if latestThermalStateTime < deadline, thermalState != ProcessInfo.ThermalState.nominal {
            thermalState = ProcessInfo.ThermalState.nominal
        }
    }

    private func makeUrl(url: String?) -> URL? {
        guard let url else {
            return nil
        }
        return URL(string: url)
    }

    private func appendInfoMessage(message: WatchProtocolChatMessage, segments: [ChatPostSegment]) {
        nextNonNormalChatLineId -= 1
        chatPosts.prepend(ChatPost(id: nextNonNormalChatLineId,
                                   kind: .info,
                                   user: "",
                                   userColor: .white,
                                   userBadges: [],
                                   segments: segments,
                                   timestamp: message.timestamp))
    }

    private func appendRedLineMessage(message: WatchProtocolChatMessage) {
        nextNonNormalChatLineId -= 1
        chatPosts.prepend(ChatPost(id: nextNonNormalChatLineId,
                                   kind: .redLine,
                                   user: "",
                                   userColor: .red,
                                   userBadges: [],
                                   segments: [],
                                   timestamp: message.timestamp))
    }

    private func handleChatMessage(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolChatMessage.self, from: data)
        // Latest received message is often retransmitted. Just ignore it if so (or likely so).
        if message.id == chatPosts.first?.id {
            return
        }
        if message.id < nextExpectedWatchChatPostId {
            nextExpectedWatchChatPostId = message.id
            chatPosts.removeAll()
            numberOfNormalPostsInChat = 0
            latestChatMessageTime = .now
            appendInfoMessage(message: message, segments: [
                .init(text: "Reconnected."),
            ])
        }
        let numberOfDiscardedChatMessages = message.id - nextExpectedWatchChatPostId
        if numberOfDiscardedChatMessages > 0 {
            appendInfoMessage(message: message, segments: [
                .init(text: String(numberOfDiscardedChatMessages)),
                .init(text: numberOfDiscardedChatMessages == 1 ? "message" : "messages"),
                .init(text: "discarded."),
            ])
        }
        nextExpectedWatchChatPostId = message.id + 1
        let now = ContinuousClock.now
        if latestChatMessageTime + .seconds(30) < now {
            appendRedLineMessage(message: message)
            if settings.chat.notificationOnMessage! {
                WKInterfaceDevice.current().play(.notification)
            }
        }
        latestChatMessageTime = now
        chatPosts.prepend(
            ChatPost(id: message.id,
                     kind: .normal,
                     user: message.user,
                     userColor: message.userColor.color(),
                     userBadges: message.userBadges,
                     segments: message.segments.map { ChatPostSegment(
                         text: $0.text,
                         url: makeUrl(url: $0.url)
                     ) },
                     timestamp: message.timestamp,
                     highlight: message.highlight.map { ChatPostHighlight.fromWatchProtocol(highlight: $0) })
        )
        numberOfNormalPostsInChat += 1
        while numberOfNormalPostsInChat > maximumNumberOfWatchChatMessages {
            if chatPosts.popLast()?.kind == .normal {
                numberOfNormalPostsInChat -= 1
            }
        }
    }

    private func handleSpeedAndTotal(_ data: Any) throws {
        guard let speedAndTotal = data as? String else {
            return
        }
        self.speedAndTotal = speedAndTotal
        latestSpeedAndTotalTime = .now
    }

    private func handleRecordingLength(_ data: Any) throws {
        guard let recordingLength = data as? String else {
            return
        }
        self.recordingLength = recordingLength
        latestRecordingLengthTime = .now
    }

    private func handleAudioLevel(_ data: Any) throws {
        guard let audioLevel = data as? Float else {
            return
        }
        self.audioLevel = audioLevel
        latestAudioLevelTime = .now
    }

    private func handleIsLive(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isLive = value
    }

    private func handleIsRecording(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isRecording = value
    }

    private func handleIsMuted(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isMuted = value
    }

    private func handleSettings(_ data: Any) throws {
        guard let settings = data as? Data else {
            return
        }
        self.settings = try JSONDecoder().decode(WatchSettings.self, from: settings)
        if self.settings.chat.timestampEnabled == nil {
            self.settings.chat.timestampEnabled = false
        }
        if self.settings.chat.notificationOnMessage == nil {
            self.settings.chat.notificationOnMessage = false
        }
        if self.settings.show == nil {
            self.settings.show = .init()
        }
    }

    private func handleThermalState(_ data: Any) throws {
        guard let value = data as? Int,
              let thermalState = ProcessInfo.ThermalState(rawValue: value)
        else {
            return
        }
        self.thermalState = thermalState
        latestThermalStateTime = .now
    }

    private func handlePreview(_ data: Any) throws {
        guard let image = data as? Data else {
            return
        }
        preview = UIImage(data: image)
        showPreviewDisconnected = false
        latestPreviewTime = .now
    }

    private func handleZoom(_ data: Any) throws {
        guard let x = data as? Float else {
            return
        }
        guard !isZooming else {
            return
        }
        zoomX = Double(x)
    }

    private func handleZoomPresets(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        zoomPresets = try JSONDecoder().decode([WatchProtocolZoomPreset].self, from: data)
        updateZoomPresets()
    }

    private func handleZoomPreset(_ data: Any) throws {
        guard let data = data as? String else {
            return
        }
        guard let zoomPresetId = UUID(uuidString: data) else {
            return
        }
        self.zoomPresetId = zoomPresetId
        updateZoomPresets()
    }

    private func updateZoomPresets() {
        if zoomPresets.contains(where: { $0.id == zoomPresetId }) {
            zoomPresetIdPicker = zoomPresetId
        } else {
            zoomPresetIdPicker = nil
        }
    }

    private func handleScenes(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        scenes = try JSONDecoder().decode([WatchProtocolScene].self, from: data)
    }

    private func handleScene(_ data: Any) throws {
        guard let data = data as? String else {
            return
        }
        guard let sceneId = UUID(uuidString: data) else {
            return
        }
        self.sceneId = sceneId
        sceneIdPicker = sceneId
    }

    private func handleStartWorkout(_ data: Any) throws {
        guard let data = data as? Data else {
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolStartWorkout.self, from: data)
        handleStopWorkout()
        let configuration = HKWorkoutConfiguration()
        var activityType: HKWorkoutActivityType
        switch message.type {
        case .walking:
            activityType = .walking
            workoutType = "Walking"
        case .running:
            activityType = .running
            workoutType = "Running"
        case .cycling:
            activityType = .cycling
            workoutType = "Cycling"
        }
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        workoutSession = try? HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        guard let workoutSession else {
            return
        }
        workoutBuilder = workoutSession.associatedWorkoutBuilder()
        guard let workoutBuilder else {
            return
        }
        workoutBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        workoutSession.delegate = self
        workoutSession.startActivity(with: .now)
        workoutBuilder.delegate = self
        workoutBuilder.beginCollection(withStart: .now) { _, _ in }
    }

    private func handleStopWorkout() {
        // workoutBuilder?.discardWorkout()
        workoutBuilder?.finishWorkout { _, _ in }
        workoutSession?.end()
    }

    private func isWorkoutRunning() -> Bool {
        return workoutSession?.state == .running
    }

    func setIsLive(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsLive, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setIsRecording(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsRecording, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setIsMuted(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsMuted, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func keepAlive() {
        let message = WatchMessageFromWatch.pack(type: .keepAlive, data: true)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func skipCurrentChatTextToSpeechMessage() {
        let message = WatchMessageFromWatch.pack(type: .skipCurrentChatTextToSpeechMessage, data: true)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setZoom(x: Double) {
        let message = WatchMessageFromWatch.pack(type: .setZoom, data: Float(x))
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setZoomPreset(id: UUID) {
        let message = WatchMessageFromWatch.pack(type: .setZoomPreset, data: id.uuidString)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setScene(id: UUID) {
        let message = WatchMessageFromWatch.pack(type: .setScene, data: id.uuidString)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    private func updateWorkoutStats(stats: WatchProtocolWorkoutStats) {
        guard let stats = try? JSONEncoder().encode(stats) else {
            return
        }
        let message = WatchMessageFromWatch.pack(type: .updateWorkoutStats, data: stats)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func isShowingStatusThermalState() -> Bool {
        return settings.show!.thermalState
    }

    func isShowingStatusAudioLevel() -> Bool {
        return settings.show!.audioLevel
    }

    func isShowingStatusBitrate() -> Bool {
        return settings.show!.speed && isLive
    }

    func isShowingStatusRecording() -> Bool {
        return isRecording
    }

    func isShowingWorkout() -> Bool {
        return isWorkoutRunning()
    }
}

extension Model: WCSessionDelegate {
    func session(
        _: WCSession,
        activationDidCompleteWith _: WCSessionActivationState,
        error _: Error?
    ) {}

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let (type, data) = WatchMessageToWatch.unpack(message) else {
            return
        }
        DispatchQueue.main.async {
            self.numberOfMessagesReceived += 1
            do {
                switch type {
                case .speedAndTotal:
                    try self.handleSpeedAndTotal(data)
                case .recordingLength:
                    try self.handleRecordingLength(data)
                case .settings:
                    try self.handleSettings(data)
                case .chatMessage:
                    try self.handleChatMessage(data)
                case .preview:
                    try self.handlePreview(data)
                case .audioLevel:
                    try self.handleAudioLevel(data)
                case .isLive:
                    try self.handleIsLive(data)
                case .isRecording:
                    try self.handleIsRecording(data)
                case .isMuted:
                    try self.handleIsMuted(data)
                case .thermalState:
                    try self.handleThermalState(data)
                case .zoom:
                    try self.handleZoom(data)
                case .zoomPresets:
                    try self.handleZoomPresets(data)
                case .zoomPreset:
                    try self.handleZoomPreset(data)
                case .scenes:
                    try self.handleScenes(data)
                case .scene:
                    try self.handleScene(data)
                case .startWorkout:
                    try self.handleStartWorkout(data)
                case .stopWorkout:
                    self.handleStopWorkout()
                }
            } catch {}
        }
    }

    func sessionReachabilityDidChange(_: WCSession) {}

    func session(
        _: WCSession,
        didFinish _: WCSessionUserInfoTransfer,
        error _: (any Error)?
    ) {}
}

extension Model: HKWorkoutSessionDelegate {
    func workoutSession(
        _: HKWorkoutSession,
        didChangeTo _: HKWorkoutSessionState,
        from _: HKWorkoutSessionState,
        date _: Date
    ) {}

    func workoutSession(_: HKWorkoutSession, didFailWithError _: any Error) {}
}

extension Model: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                continue
            }
            guard let statistics = workoutBuilder.statistics(for: quantityType) else {
                continue
            }
            DispatchQueue.main.async {
                var stats = WatchProtocolWorkoutStats()
                switch statistics.quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let heartRate = statistics.mostRecentQuantity()?
                        .doubleValue(for: .count().unitDivided(by: HKUnit.minute()))
                    {
                        stats.heartRate = Int(heartRate)
                    }
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    if let activeEnergyBurned = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        stats.activeEnergyBurned = Int(activeEnergyBurned)
                    }
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                     HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                    if let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                        stats.distance = Int(distance)
                    }
                case HKQuantityType.quantityType(forIdentifier: .stepCount):
                    if let stepCount = statistics.sumQuantity()?.doubleValue(for: .count()) {
                        stats.stepCount = Int(stepCount)
                    }
                case HKQuantityType.quantityType(forIdentifier: .runningPower):
                    if let power = statistics.mostRecentQuantity()?.doubleValue(for: .watt()) {
                        stats.power = Int(power)
                    }
                default:
                    break
                }
                self.updateWorkoutStats(stats: stats)
            }
        }
    }

    func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}
}
