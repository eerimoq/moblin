import Foundation

// Goals
// - Bonding.
// - Prioritize audio over video.
// - Adaptive bitrate friendly.
// - Efficient. Low CPU usage.
// - Simple.
// - Fixed latency for video and audio?
// - Dynamic latency for data? Deliver data when available (in order).
//
// Segment type        Direction           Has SN
// ------------------------------------------------
// (0) video           client to server    yes
// (1) audio           client to server    yes
// (2) video empty     client to server    yes (same as original video (0))
// (3) audio empty     client to server    yes (same as original audio (1))
// (4) video format    client to server    yes
// (5) audio format    client to server    yes
// (6) mux             client to server    no (contained segments have)
// (7) ack             both ways           no
// (8) data            both ways           yes
//
// Comments
// - Use transport layer packet length as segment length. Typically up to 1400 bytes (roughly MTU).
// - Data (8) will need congestion control somehow. Probably as simple as a maximum number of outstanding packets.
//
// First video (0), audio (1), video format (4) or audio format (5) segment, first=1, including total length
// +---------+-------------+--------------+--------+------------------+-------------------------+
// | 5b type | 2b reserved | 1b first (1) | 24b SN | 24b total length | payload (PTS, DTS, ...) |
// +---------+-------------+--------------+--------+------------------+-------------------------+
//
// Consecutive video (0), audio (1), video format (4) or audio format (5) segment, first=0
// +---------+-------------+--------------+--------+---------+
// | 5b type | 2b reserved | 1b first (0) | 24b SN | payload |
// +---------+-------------+--------------+--------+---------+
//
// Video empty (2) or audio empty (3) segment, sent to drop given segment in receiver
// +---------+-------------+--------+--------+
// | 5b type | 3b reserved | 24b SN | 4b PTS |
// +---------+-------------+--------+--------+
//
// Mux (6) segment, containing at least two other segments
// +---------+-------------+------------+------------+------------+------------+
// | 5b type | 3b reserved | 16b length | segment #1 | 16b length | segment #2 |
// +---------+-------------+------------+------------+------------+------------+
//
// Ack (7) segment, sent every 50 ms on all connections
// +---------+-------------+----------------+--------+--------+--------+--------+--------+
// | 5b type | 3b reserved | 8b singles (3) | 24b SN | 24b SN | 24b SN | 24b SN | 24b SN |
// +---------+-------------+----------------+--------+--------+--------+--------+--------+
//                                            single   single   single        range
//
// First data (8) segment, first=1, including total length
// +---------+-------------+--------------+--------+------------------+---------+
// | 5b type | 2b reserved | 1b first (1) | 24b SN | 24b total length | payload |
// +---------+-------------+--------------+--------+------------------+---------+
//
// Consecutive data (8) segment, first=0
// +---------+-------------+--------------+--------+---------+
// | 5b type | 2b reserved | 1b first (0) | 24b SN | payload |
// +---------+-------------+--------------+--------+---------+
//
