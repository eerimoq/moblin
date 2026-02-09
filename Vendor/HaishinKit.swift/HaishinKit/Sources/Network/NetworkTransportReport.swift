import Foundation

/// A structure that represents a network transport bitRate statics.
package struct NetworkTransportReport: Sendable {
    /// The statistics of outgoing queue bytes per second.
    package let queueBytesOut: Int
    /// The statistics of incoming bytes per second.
    package let totalBytesIn: Int
    /// The statistics of outgoing bytes per second.
    package let totalBytesOut: Int

    /// Creates a new instance.
    package init(queueBytesOut: Int, totalBytesIn: Int, totalBytesOut: Int) {
        self.queueBytesOut = queueBytesOut
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
    }
}
