import argparse
import json
import queue
import socket
import struct
import subprocess
import sys
import threading
import time

from usbmux import UsbmuxError
from usbmux import connect as usbmux_connect

MAGIC = b"MOBL"
VERSION = 1

MESSAGE_HOST_HELLO = 0x01
MESSAGE_DEVICE_HELLO = 0x02
MESSAGE_VIDEO_CONFIG = 0x03
MESSAGE_VIDEO_FRAME = 0x04
MESSAGE_AUDIO_CONFIG = 0x05
MESSAGE_AUDIO_FRAME = 0x06

VIDEO_CODECS = {0: "h264", 1: "hevc"}

START_CODE = b"\x00\x00\x00\x01"

MEASURE_SECONDS = 1.0


def pack_message(message_type: int, payload: bytes) -> bytes:
    return struct.pack(">IB", len(payload) + 1, message_type) + payload


class MessageReader:
    def __init__(self) -> None:
        self.buffer = b""

    def append(self, data: bytes) -> None:
        self.buffer += data

    def read(self) -> tuple[int, bytes] | None:
        if len(self.buffer) < 4:
            return None
        (length,) = struct.unpack(">I", self.buffer[:4])
        if length < 1:
            raise ValueError(f"Bad message length {length}")
        if len(self.buffer) < 4 + length:
            return None
        message_type = self.buffer[4]
        payload = self.buffer[5 : 4 + length]
        self.buffer = self.buffer[4 + length :]
        return message_type, payload


def parse_avcc(record: bytes) -> bytes:
    parameter_sets = b""
    number_of_sps = record[5] & 0x1F
    offset = 6
    for _ in range(number_of_sps):
        (length,) = struct.unpack(">H", record[offset : offset + 2])
        offset += 2
        parameter_sets += START_CODE + record[offset : offset + length]
        offset += length
    number_of_pps = record[offset]
    offset += 1
    for _ in range(number_of_pps):
        (length,) = struct.unpack(">H", record[offset : offset + 2])
        offset += 2
        parameter_sets += START_CODE + record[offset : offset + length]
        offset += length
    return parameter_sets


def parse_hvcc(record: bytes) -> bytes:
    parameter_sets = b""
    number_of_arrays = record[22]
    offset = 23
    for _ in range(number_of_arrays):
        offset += 1
        (number_of_units,) = struct.unpack(">H", record[offset : offset + 2])
        offset += 2
        for _ in range(number_of_units):
            (length,) = struct.unpack(">H", record[offset : offset + 2])
            offset += 2
            parameter_sets += START_CODE + record[offset : offset + length]
            offset += length
    return parameter_sets


def to_annex_b(units: bytes) -> bytes:
    annex_b = b""
    offset = 0
    while offset + 4 <= len(units):
        (length,) = struct.unpack(">I", units[offset : offset + 4])
        offset += 4
        annex_b += START_CODE + units[offset : offset + length]
        offset += length
    return annex_b


class SinkClosed(Exception):
    pass


class Sink:
    def __init__(self, output: str | None) -> None:
        self.output = output
        self.process: subprocess.Popen[bytes] | None = None
        self.player: subprocess.Popen[bytes] | None = None
        self.video_codec = ""
        self.video_queue: queue.Queue[bytes | None] = queue.Queue(maxsize=120)
        self.thread: threading.Thread | None = None
        self.failed = False
        self.dropped = 0

    def start(self, video_codec: str, fps: int) -> None:
        self.video_codec = video_codec
        command = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-fflags",
            "nobuffer",
            "-flags",
            "low_delay",
            "-thread_queue_size",
            "512",
            "-r",
            str(fps),
            "-f",
            video_codec,
            "-i",
            "pipe:0",
            "-c",
            "copy",
        ]
        if self.output is not None:
            command += ["-y", self.output]
            stdout = None
        else:
            command += [
                "-muxdelay",
                "0",
                "-muxpreload",
                "0",
                "-flush_packets",
                "1",
                "-f",
                "mpegts",
                "pipe:1",
            ]
            stdout = subprocess.PIPE
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=stdout,
            start_new_session=True,
        )
        if self.output is None:
            self.player = subprocess.Popen(
                [
                    "ffplay",
                    "-hide_banner",
                    "-loglevel",
                    "warning",
                    "-fflags",
                    "nobuffer",
                    "-flags",
                    "low_delay",
                    "-framedrop",
                    "-i",
                    "pipe:0",
                ],
                stdin=self.process.stdout,
                start_new_session=True,
            )
        self.thread = threading.Thread(target=self.pump_video, daemon=True)
        self.thread.start()

    def pump_video(self) -> None:
        while True:
            data = self.video_queue.get()
            if data is None:
                return
            if self.process is None or self.process.stdin is None:
                return
            try:
                self.process.stdin.write(data)
                self.process.stdin.flush()
            except (OSError, ValueError):
                self.failed = True
                return

    def enqueue(self, target: "queue.Queue[bytes | None]", data: bytes) -> None:
        if self.failed:
            raise SinkClosed()
        try:
            target.put_nowait(data)
        except queue.Full:
            self.dropped += 1

    def depths(self) -> str:
        return f"queued={self.video_queue.qsize()} dropped={self.dropped}"

    def write_video(self, data: bytes) -> None:
        self.enqueue(self.video_queue, data)

    def stop(self) -> None:
        try:
            self.video_queue.put(None, timeout=5)
        except queue.Full:
            pass
        if self.thread is not None:
            self.thread.join(timeout=5)
        if self.process is not None and self.process.stdin is not None:
            try:
                self.process.stdin.close()
            except BrokenPipeError:
                pass
        for process in [self.process, self.player]:
            if process is None:
                continue
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait()


class Statistics:
    def __init__(self, sink: "Sink") -> None:
        self.sink = sink
        self.frames = 0
        self.byte_count = 0
        self.reported_at = time.monotonic()
        self.offset: float | None = None

    def update(self, presentation_time_stamp: int, length: int) -> None:
        self.frames += 1
        self.byte_count += length
        now = time.monotonic()
        offset = now - presentation_time_stamp / 1e6
        if self.offset is None:
            self.offset = offset
        elapsed = now - self.reported_at
        if elapsed < 2:
            return
        drift = 1000 * (offset - self.offset)
        print(
            f"{self.frames / elapsed:.1f} fps, "
            f"{8 * self.byte_count / elapsed / 1e6:.1f} Mbps, "
            f"drift {drift:+.0f} ms, {self.sink.depths()}",
            file=sys.stderr,
        )
        self.frames = 0
        self.byte_count = 0
        self.reported_at = now


class Receiver:
    def __init__(self, sink: Sink) -> None:
        self.sink = sink
        self.reader = MessageReader()
        self.statistics = Statistics(sink)
        self.video_parameter_sets = b""
        self.video_codec = ""
        self.started = False
        self.timestamps: list[int] = []
        self.pending_video: list[bytes] = []

    def handle_device_hello(self, payload: bytes) -> None:
        (length,) = struct.unpack(">I", payload[1:5])
        info = json.loads(payload[5 : 5 + length])
        print(
            f"Streaming from {info['name']} running Moblin {info['version']}",
            file=sys.stderr,
        )

    def handle_video_config(self, payload: bytes) -> None:
        codec = VIDEO_CODECS.get(payload[0])
        if codec is None:
            raise ValueError(f"Unsupported video codec {payload[0]}")
        width, height = struct.unpack(">HH", payload[1:5])
        (length,) = struct.unpack(">I", payload[5:9])
        record = payload[9 : 9 + length]
        if codec == "h264":
            self.video_parameter_sets = parse_avcc(record)
        else:
            self.video_parameter_sets = parse_hvcc(record)
        self.video_codec = codec
        print(f"Video is {codec} {width}x{height}", file=sys.stderr)

    def handle_video_frame(self, payload: bytes) -> None:
        (presentation_time_stamp,) = struct.unpack(">Q", payload[:8])
        units = to_annex_b(payload[9:])
        if payload[8] == 1:
            units = self.video_parameter_sets + units
        self.statistics.update(presentation_time_stamp, len(payload))
        if self.started:
            self.sink.write_video(units)
            return
        self.pending_video.append(units)
        self.timestamps.append(presentation_time_stamp)
        self.start_when_rate_is_known()

    def start_when_rate_is_known(self) -> None:
        if self.video_codec == "":
            return
        span = (self.timestamps[-1] - self.timestamps[0]) / 1e6
        if span < MEASURE_SECONDS or len(self.timestamps) < 2:
            return
        fps = round((len(self.timestamps) - 1) / span)
        print(f"Measured {fps} fps", file=sys.stderr)
        self.sink.start(self.video_codec, max(1, fps))
        self.started = True
        for units in self.pending_video:
            self.sink.write_video(units)
        self.pending_video.clear()

    def handle_message(self, message_type: int, payload: bytes) -> None:
        handlers = {
            MESSAGE_DEVICE_HELLO: self.handle_device_hello,
            MESSAGE_VIDEO_CONFIG: self.handle_video_config,
            MESSAGE_VIDEO_FRAME: self.handle_video_frame,
        }
        handler = handlers.get(message_type)
        if handler is None:
            return
        handler(payload)

    def receive(self, sock: socket.socket) -> None:
        sock.sendall(pack_message(MESSAGE_HOST_HELLO, MAGIC + bytes([VERSION])))
        while True:
            data = sock.recv(65536)
            if not data:
                print("Device closed the connection", file=sys.stderr)
                return
            self.reader.append(data)
            while True:
                message = self.reader.read()
                if message is None:
                    break
                self.handle_message(*message)


def main() -> None:
    parser = argparse.ArgumentParser(description="Receive a Moblin USB stream.")
    parser.add_argument("-p", "--port", type=int, default=7777, help="Port Moblin listens on.")
    parser.add_argument("-s", "--serial", help="Serial number of the device to use.")
    parser.add_argument(
        "-a",
        "--address",
        help="Connect to HOST:PORT over the network instead of over USB.",
    )
    parser.add_argument("-o", "--output", help="Write the stream to this file.")
    args = parser.parse_args()
    if args.address is not None:
        host, _, port = args.address.rpartition(":")
        sock = socket.create_connection((host, int(port)))
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        print(f"Connected to {args.address}", file=sys.stderr)
    else:
        try:
            sock, serial = usbmux_connect(args.port, args.serial)
        except UsbmuxError as error:
            sys.exit(str(error))
        print(f"Connected to {serial} over USB", file=sys.stderr)
    sink = Sink(args.output)
    try:
        Receiver(sink).receive(sock)
    except KeyboardInterrupt:
        pass
    except SinkClosed:
        print("ffmpeg or ffplay exited", file=sys.stderr)
    finally:
        sock.close()
        sink.stop()


main()
