import Foundation

struct RtmpStreamMetrics: Codable {
    let timestamp: Date
    let instantBitrate: Int // bps calculado nos últimos 1-2s
    let bytesSentTotal: UInt64
    let estimatedRttMs: Double? // baseado em ACK timing
    let sendBufferUtilization: Double // 0.0 a 1.0
    let currentChunkSize: Int
    let reconnectAttempts: Int
    let videoTimestampDrift: TimeInterval
    let audioTimestampDrift: TimeInterval
    let lastReconnectReason: String?

    // Helper para UI
    var healthScore: Double {
        // 0.0 = péssimo, 1.0 = excelente
        let rttFactor = min(1.0, 200.0 / (estimatedRttMs ?? 150.0))
        let bufferFactor = max(0.0, 1.0 - sendBufferUtilization)
        let reconnectFactor = max(0.0, 1.0 - Double(reconnectAttempts) * 0.05)
        return min(1.0, max(0.0, rttFactor * 0.4 + bufferFactor * 0.4 + reconnectFactor * 0.2))
    }
}
