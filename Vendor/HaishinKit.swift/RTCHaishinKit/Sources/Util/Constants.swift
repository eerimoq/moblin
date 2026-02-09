import Logboard

/// The identifier for the HaishinKit WebRTC integration.
public let kRTCHaishinKitIdentifier = "com.haishinkit.RTCHaishinKit"

nonisolated(unsafe) let logger = LBLogger.with(kRTCHaishinKitIdentifier)
