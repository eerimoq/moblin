# Moblin Mobcam protocol

Moblin can stream to a computer over the USB cable, mainly to use the phone as a low latency webcam.
Select it by setting the stream URL to `mobcam://localhost:7777`, where the port number is the port Moblin
listens on. The create stream wizard has a Mobcam entry under Custom that fills this in.

Only AAC audio is supported. Moblin streams video only if the audio codec is set to something else.

## Transport

iOS does not give apps direct access to USB. The only channel available is usbmux, the same mechanism
`iproxy` and Xcode use, where the *computer* opens a TCP connection to a port on the *device*. There is
no device to computer direction. Moblin is therefore a server: going live opens a listener on
`127.0.0.1:<port>`, and the computer connects to it through usbmux.

`utils/mobcam_host.py` is a reference receiver. It opens the usbmux tunnel, decodes the protocol and pipes
the result to `ffplay`, or writes it to a file with `--output`.

```sh
python utils/mobcam_host.py
python utils/mobcam_host.py --output webcam.mkv
python utils/mobcam_host.py --address 192.168.0.10:7777
```

It handles **video only** for now. It converts the video to Annex-B and pipes it to `ffmpeg` as an
elementary stream, so it does not carry the timestamps below into the file it writes and lets `ffmpeg`
generate them from a frame rate it measures off the wire timestamps over the first second. It reports the
drift it sees but otherwise ignores the audio messages. A receiver that needs the real timestamps, such
as a virtual camera, should mux them itself.

Two things about this are worth knowing before writing another receiver. `ffmpeg`'s raw `h264` demuxer
honours `-r` but not `-framerate`; with `-framerate` every packet comes out with a presentation
timestamp of zero. And a receiver must never let a stalled sink block it from reading the socket, or the
flow control below starts dropping video. The reference receiver writes to `ffmpeg` from its own thread
with a bounded queue for exactly that reason.

The link is lossless and ordered, so there is no retransmission, no forward error correction, no
congestion control and no muxing layer. Nothing is aggregated either. Every message is written to the
socket the moment it is produced, with `TCP_NODELAY` set.

## Framing

All integers are big endian. Every message is

```
u32 payloadLength      excluding these four bytes
u8  messageType
... payload
```

The maximum payload length is 4 MB.

### Computer to device

The computer sends this first. Moblin drops connections that do not say hello within five seconds, and
connections that say hello with a version it does not implement.

| Type | Name  | Payload                                      |
|------|-------|----------------------------------------------|
| 0x01 | hello | `"MOBL"`, `u8` protocol version (currently 1) |

### Device to computer

| Type | Name        | Payload                                                                              |
|------|-------------|--------------------------------------------------------------------------------------|
| 0x02 | hello       | `u8` version, `u32` length, UTF-8 JSON `{"name": …, "version": …}`                     |
| 0x03 | videoConfig | `u8` codec (0 = H.264, 1 = HEVC), `u16` width, `u16` height, `u32` length, `avcC`/`hvcC` |
| 0x04 | videoFrame  | `u64` presentation timestamp, `u8` flags (bit 0 = keyframe), access unit               |
| 0x05 | audioConfig | `u8` codec (0 = AAC-LC), `u32` sample rate, `u8` channels, `u32` length, AudioSpecificConfig |
| 0x06 | audioFrame  | `u64` presentation timestamp, one access unit                                          |

Video and audio access units are exactly what VideoToolbox and the AAC encoder produce. Video is AVCC,
that is, each NAL unit prefixed by its `u32` length, not Annex-B. The configuration records are the
`avcC` and `hvcC` atoms, so a receiver can pass them to a decoder as extradata unmodified.

A config message is sent before the first frame that uses it and again whenever the format changes. The frame rate is
not sent. A receiver that needs it estimates it from the timestamps.

Timestamps are in microseconds and are not rebased. They are the capture presentation timestamps on the
device clock, which video and audio share, so lip sync is exact. The device clock has an unrelated
origin to the computer clock, so a receiver that wants a zero based timeline subtracts the first
timestamp it sees.

## Encoding and flow control

Moblin starts the encoder when the computer connects and stops it when the computer disconnects. A
fresh encoder session means the first frame the computer receives is always a keyframe with fresh
parameter sets, so there is no request round trip on connect, and nothing is encoded while no computer
is attached.

Frame reordering is turned off for this transport, so there are no B-frames and the decode timestamp
always equals the presentation timestamp.

TCP with a slow reader grows latency without bound, which would defeat the point. Moblin tracks how many
bytes are outstanding in the socket. Above one megabyte it drops video frames until the next keyframe,
and if the backlog persists for five seconds it closes the connection, treating the computer as hung.
The listener stays up across all of this, so reconnecting is immediate.

There is no authentication and no encryption. Reaching the port requires a USB cable and an existing
trust pairing, and the listener is bound to loopback so it is not reachable from the network.
