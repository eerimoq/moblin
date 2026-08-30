# Moblin Mobcam protocol

Moblin can stream to a computer over USB, mainly to use the phone as a low latency webcam.
Select it by setting the stream URL to `mobcam://localhost:7790`, where the port number is the port Moblin
listens on.

## Framing

All integers are big endian. Every message is

```
u8  messageType
u32 payloadLength      excluding these five bytes
... payload
```

### Computer to device

The computer sends this first. Moblin drops connections that do not say hello within five seconds, and
connections that say hello with a version it does not implement.

| Type | Name  | Payload                             |
|------|-------|-------------------------------------|
| 0x01 | hello | `u8` protocol version (currently 1) |

### Device to computer

| Type | Name        | Payload                                                                              |
|------|-------------|--------------------------------------------------------------------------------------|
| 0x02 | hello       | `u8` version, `u32` length, UTF-8 JSON `{"name": …, "version": …}`                     |
| 0x03 | videoConfig | `u8` codec (0 = H.264, 1 = HEVC), `u16` width, `u16` height, `u32` length, `avcC`/`hvcC` |
| 0x04 | videoFrame  | `u64` presentation timestamp, `u8` flags (bit 0 = keyframe), access unit               |
| 0x05 | audioConfig | `u8` codec (0 = AAC-LC, 1 = Opus), `u32` sample rate, `u8` channels, `u32` length, AudioSpecificConfig/`OpusHead` |
| 0x06 | audioFrame  | `u64` presentation timestamp, one access unit                                          |

The audio configuration record is an `AudioSpecificConfig` for AAC-LC and an `OpusHead` identification
header (RFC 7845, little endian, pre-skip and output gain always zero) for Opus. One Opus audio frame
message carries one Opus packet.
