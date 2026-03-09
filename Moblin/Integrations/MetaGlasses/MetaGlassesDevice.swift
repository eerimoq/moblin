import CoreMedia
import Foundation
import MWDATCamera
import MWDATCore

private let metaGlassesStreamLatency = 0.1

enum MetaGlassesRegistrationState {
    case unregistered
    case registering
    case registered

    func toString() -> String {
        switch self {
        case .unregistered:
            return String(localized: "Unregistered")
        case .registering:
            return String(localized: "Registering...")
        case .registered:
            return String(localized: "Registered")
        }
    }
}

enum MetaGlassesStreamingState {
    case stopped
    case waiting
    case streaming

    func toString() -> String {
        switch self {
        case .stopped:
            return String(localized: "Stopped")
        case .waiting:
            return String(localized: "Waiting...")
        case .streaming:
            return String(localized: "Streaming")
        }
    }
}

protocol MetaGlassesDeviceDelegate: AnyObject {
    func metaGlassesDeviceConnected()
    func metaGlassesDeviceDisconnected()
    func metaGlassesDeviceVideoBuffer(_ sampleBuffer: CMSampleBuffer)
    func metaGlassesDeviceRegistrationStateChanged(_ state: MetaGlassesRegistrationState)
    func metaGlassesDeviceStreamingStateChanged(_ state: MetaGlassesStreamingState)
    func metaGlassesDeviceError(_ message: String)
}

class MetaGlassesDevice {
    weak var delegate: MetaGlassesDeviceDelegate?

    private var wearables: WearablesInterface?
    private var streamSession: StreamSession?
    private var deviceSelector: AutoDeviceSelector?
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?
    private var deviceMonitorTask: Task<Void, Never>?
    private(set) var registrationState: MetaGlassesRegistrationState = .unregistered
    private(set) var streamingState: MetaGlassesStreamingState = .stopped
    private(set) var hasActiveDevice = false
    private(set) var isConfigured = false

    init() {}

    deinit {
        stop()
    }

    func configure() {
        guard !isConfigured else { return }
        do {
            try Wearables.configure()
            wearables = Wearables.shared
            isConfigured = true
        } catch {
            logger.info("meta-glasses: Failed to configure MWDAT SDK: \(error)")
        }
    }

    func start() {
        guard isConfigured, let wearables else { return }

        registrationTask = Task { @MainActor in
            for await state in wearables.registrationStateStream() {
                self.updateRegistrationState(state)
            }
        }

        deviceStreamTask = Task { @MainActor in
            for await _ in wearables.devicesStream() {
                // Device list updated
            }
        }
    }

    func stop() {
        stopStreaming()
        registrationTask?.cancel()
        registrationTask = nil
        deviceStreamTask?.cancel()
        deviceStreamTask = nil
    }

    func handleUrl(_ url: URL) async throws {
        guard isConfigured else { return }
        _ = try await Wearables.shared.handleUrl(url)
    }

    // MARK: - Registration

    func connectGlasses() {
        guard let wearables, registrationState != .registering else { return }
        Task { @MainActor in
            do {
                try await wearables.startRegistration()
            } catch let error as RegistrationError {
                self.delegate?.metaGlassesDeviceError(String(localized: "Registration failed: \(error.description)"))
            } catch {
                self.delegate?.metaGlassesDeviceError(String(localized: "Registration failed: \(error.localizedDescription)"))
            }
        }
    }

    func disconnectGlasses() {
        guard let wearables else { return }
        stopStreaming()
        Task { @MainActor in
            do {
                try await wearables.startUnregistration()
            } catch {
                self.delegate?.metaGlassesDeviceError(
                    String(localized: "Disconnect failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Streaming

    func startStreaming(resolution: SettingsMetaGlassesResolution, frameRate: Int) {
        guard let wearables, registrationState == .registered else { return }

        let sdkResolution = mapResolution(resolution)
        let sdkFrameRate = UInt(frameRate)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let selector = AutoDeviceSelector(wearables: wearables)
            self.deviceSelector = selector

            let config = StreamSessionConfig(
                videoCodec: VideoCodec.raw,
                resolution: sdkResolution,
                frameRate: sdkFrameRate
            )
            let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
            self.streamSession = session

            self.deviceMonitorTask = Task { @MainActor in
                for await device in selector.activeDeviceStream() {
                    let wasActive = self.hasActiveDevice
                    self.hasActiveDevice = device != nil
                    if self.hasActiveDevice, !wasActive {
                        self.delegate?.metaGlassesDeviceConnected()
                    } else if !self.hasActiveDevice, wasActive {
                        self.delegate?.metaGlassesDeviceDisconnected()
                    }
                }
            }

            self.stateListenerToken = session.statePublisher.listen { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleStreamStateChange(state)
                }
            }

            self.videoFrameListenerToken = session.videoFramePublisher.listen { [weak self] (videoFrame: VideoFrame) in
                let sampleBuffer = videoFrame.sampleBuffer
                self?.delegate?.metaGlassesDeviceVideoBuffer(sampleBuffer)
            }

            self.errorListenerToken = session.errorPublisher.listen { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.handleStreamError(error)
                }
            }

            await self.checkPermissionsAndStart(session: session)
        }
    }

    func stopStreaming() {
        guard let session = streamSession else { return }
        stateListenerToken = nil
        videoFrameListenerToken = nil
        errorListenerToken = nil
        deviceMonitorTask?.cancel()
        deviceMonitorTask = nil
        Task {
            await session.stop()
        }
        streamSession = nil
        deviceSelector = nil
        streamingState = .stopped
        delegate?.metaGlassesDeviceStreamingStateChanged(.stopped)
    }

    // MARK: - Private

    private func updateRegistrationState(_ state: RegistrationState) {
        switch state {
        case .registered:
            registrationState = .registered
        case .registering:
            registrationState = .registering
        case .unavailable, .available:
            registrationState = .unregistered
        @unknown default:
            registrationState = .unregistered
        }
        delegate?.metaGlassesDeviceRegistrationStateChanged(registrationState)
    }

    private func checkPermissionsAndStart(session: StreamSession) async {
        guard let wearables else { return }
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            if status == .granted {
                await session.start()
                return
            }
            let requestStatus = try await wearables.requestPermission(.camera)
            if requestStatus == .granted {
                await session.start()
            } else {
                delegate?.metaGlassesDeviceError(String(localized: "Camera permission denied"))
            }
        } catch {
            delegate?.metaGlassesDeviceError(String(localized: "Permission error: \(error.localizedDescription)"))
        }
    }

    private func handleStreamStateChange(_ state: StreamSessionState) {
        switch state {
        case .stopped:
            streamingState = .stopped
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingState = .waiting
        case .streaming:
            streamingState = .streaming
        @unknown default:
            streamingState = .stopped
        }
        delegate?.metaGlassesDeviceStreamingStateChanged(streamingState)
    }

    private func handleStreamError(_ error: StreamSessionError) {
        let message: String
        switch error {
        case .internalError:
            message = String(localized: "Internal streaming error")
        case .deviceNotFound:
            message = String(localized: "Glasses not found")
        case .deviceNotConnected:
            message = String(localized: "Glasses not connected")
        case .timeout:
            message = String(localized: "Connection timed out")
        case .videoStreamingError:
            message = String(localized: "Video streaming failed")
        case .audioStreamingError:
            message = String(localized: "Audio streaming failed")
        case .permissionDenied:
            message = String(localized: "Camera permission denied")
        case .hingesClosed:
            message = String(localized: "Glasses hinges are closed")
        @unknown default:
            message = String(localized: "Unknown streaming error")
        }
        delegate?.metaGlassesDeviceError(message)
    }

    private func mapResolution(_ resolution: SettingsMetaGlassesResolution) -> StreamingResolution {
        switch resolution {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        }
    }
}
