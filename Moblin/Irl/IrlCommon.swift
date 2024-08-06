import Foundation

// - Fixed latency.
// - Bonding.
// - Prioritize audio over video.
// - Adaptive bitrate friendly.
//
// Types
// (1) Video
// (2) Audio
// (3) Video format
// (4) Audio format
// (5) Ack
//
// SN per type.
//
// First video/audio packet
// +---------+---+--------+------------------+---------+
// | 7b type | 1 | 24b SN | 24b total length | Payload |
// +---------+---+--------+------------------+---------+
//
// Video/audio packet
// +---------+---+--------+---------+
// | 7b type | 0 | 24b SN | Payload |
// +---------+---+--------+---------+
//
// Ack packet (sent every 50 ms on all connections)
// +---------+---+--------+---------+---+------------+-----+------------+---------+-- - -
// | 7b type | 1 | 24b SN | 7b type | - | 16b length | SN1 | SN3 - SN30 | 7b type | ...
// +---------+---+--------+---------+---+------------+-----+------------+---------+-- - -
