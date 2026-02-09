import libdatachannel

/// An actor for writing interpolated string messages to `libdatachannel` logging system.
public actor RTCLogger {
    /// Defines the logging severity levels supported by `libdatachannel`.
    public enum Level {
        /// No logs will be emitted.
        case none
        /// Fatal errors.
        case fatal
        /// Recoverable errors.
        case error
        /// Potential issues that should be noted.
        case warning
        /// General informational messages.
        case info
        /// Debug messages for development and troubleshooting.
        case debug
        /// Verbose messages for detailed tracing.
        case verbose

        var cValue: rtcLogLevel {
            switch self {
            case .none:
                return RTC_LOG_NONE
            case .fatal:
                return RTC_LOG_FATAL
            case .error:
                return RTC_LOG_ERROR
            case .warning:
                return RTC_LOG_WARNING
            case .info:
                return RTC_LOG_INFO
            case .debug:
                return RTC_LOG_DEBUG
            case .verbose:
                return RTC_LOG_VERBOSE
            }
        }
    }

    /// The singleton logger instance.
    public static let shared = RTCLogger()

    /// The current logging level.
    public private(set) var level: Level = .none

    /// Sets the current logging level.
    public func setLevel(_ level: Level) {
        rtcInitLogger(level.cValue, nil)
    }
}
