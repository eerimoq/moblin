import Logboard

/// The identifier for the HaishinKit RTMP integration.
public let kRTMPHaishinKitIdentifier = "com.haishinkit.RTMPHaishinKit"

nonisolated(unsafe) let logger = LBLogger.with(kRTMPHaishinKitIdentifier)
