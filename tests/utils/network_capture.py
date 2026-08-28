import json
import logging
import re
import struct
import subprocess
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from humanfriendly import format_size
from humanfriendly import format_timespan
from systest import ManagedProcess
from systest import wait_until

from .ffmpeg import file_size
from .monitor import log_table
from .traffic_shaper import PROTOCOL_NUMBERS
from .traffic_shaper import Protocol

LOGGER = logging.getLogger(__name__)

SNAPSHOT_LENGTH = 128
READ_SIZE = 4 * 1024 * 1024
OTHER_NAME = "Other"
TEMPLATE_FILE = Path(__file__).parent / "network_capture.html"
PROTOCOLS = {number: protocol for protocol, number in PROTOCOL_NUMBERS.items()}
PCAP_MAGIC_MICROSECONDS = 0xA1B2C3D4
PCAP_MAGIC_NANOSECONDS = 0xA1B23C4D
LINK_TYPE_NULL = 0
LINK_TYPE_ETHERNET = 1
ETHERNET_TYPE_IPV4 = 0x0800
ETHERNET_TYPE_IPV6 = 0x86DD
ETHERNET_TYPE_VLAN = 0x8100
NULL_FAMILY_IPV4 = 2
NULL_FAMILY_IPV6 = 30


@dataclass
class CaptureStream:
    name: str
    protocol: Protocol
    port: int


@dataclass
class Series:
    name: str
    slot: int
    total_bytes: int
    bitrates: list[float]

    def maximum_mbps(self) -> float:
        return max(self.bitrates, default=0)

    def average_mbps(self, duration: float) -> float:
        return 8 * self.total_bytes / duration / 1e6


@dataclass
class CaptureReport:
    start_time: float
    duration: float
    files: list[Path]
    series: list[Series]
    total_slot: int
    settings: dict[str, str]

    def log(self):
        log_table(
            "Captured bitrates",
            ["Average Mbps", "Maximum Mbps", "Total"],
            [
                [
                    series.name,
                    f"{series.average_mbps(self.duration):.1f}",
                    f"{series.maximum_mbps():.1f}",
                    format_size(series.total_bytes),
                ]
                for series in self.series
            ],
        )

    def write_html(self, output: Path):
        data = {
            "startTime": datetime.fromtimestamp(self.start_time).strftime("%Y-%m-%d %H:%M:%S"),
            "duration": format_timespan(round(self.duration)),
            "files": ", ".join(file.name for file in self.files),
            "totalSlot": self.total_slot,
            "settings": [{"name": name, "value": value} for name, value in self.settings.items()],
            "series": [
                {
                    "name": series.name,
                    "slot": series.slot,
                    "totalBytes": series.total_bytes,
                    "bitrates": series.bitrates,
                }
                for series in self.series
            ],
        }
        template = TEMPLATE_FILE.read_text()
        output.write_text(template.replace('"__CAPTURE_DATA__"', json.dumps(data)))


class Bitrates:
    def __init__(self, streams: list[CaptureStream], settings: dict[str, str]):
        self._names = list(dict.fromkeys([stream.name for stream in streams] + [OTHER_NAME]))
        self._ports = {(stream.protocol, stream.port): stream.name for stream in streams}
        self._buckets: dict[str, dict[int, int]] = {name: defaultdict(int) for name in self._names}
        self._settings = settings
        self._files: list[Path] = []

    def add_file(self, file: Path):
        self._files.append(file)
        ports = self._ports
        buckets = self._buckets
        other = buckets[OTHER_NAME]
        for timestamp, protocol, source_port, destination_port, length in read_packets(file):
            name = ports.get((protocol, destination_port), ports.get((protocol, source_port)))
            if name is None:
                other[int(timestamp)] += length
            else:
                buckets[name][int(timestamp)] += length

    def report(self) -> CaptureReport:
        used = [buckets for buckets in self._buckets.values() if buckets]
        if not used:
            raise Exception("No packets in the network capture.")
        first = min(min(buckets) for buckets in used)
        last = max(max(buckets) for buckets in used)
        return CaptureReport(
            start_time=first,
            duration=last - first + 1,
            files=self._files,
            total_slot=len(self._names),
            settings=self._settings,
            series=[
                Series(
                    name=name,
                    slot=slot,
                    total_bytes=sum(self._buckets[name].values()),
                    bitrates=[
                        round(8 * self._buckets[name].get(second, 0) / 1e6, 3)
                        for second in range(first, last + 1)
                    ],
                )
                for slot, name in enumerate(self._names)
                if self._buckets[name]
            ],
        )


class NetworkCapture:
    def __init__(
        self,
        hosts: list[str],
        directory: Path,
        name: str,
        streams: list[CaptureStream],
        settings: dict[str, str],
    ):
        self._hosts = hosts
        self._directory = directory
        self._name = name
        self._streams = streams
        self._settings = settings
        self._processes: list[ManagedProcess] = []
        self.files: list[Path] = []

    def __enter__(self):
        try:
            for interface in sorted({find_interface(host) for host in self._hosts}):
                self._start(interface)
        except BaseException:
            self.stop()
            raise
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()

    def poll(self):
        for process in [process for process in self._processes if not process.is_running()]:
            LOGGER.warning("A network capture exited. No longer capturing all packets.")
            self._processes.remove(process)

    def stop(self):
        for process in self._processes:
            process.stop()
        self._processes = []
        for file in self.files:
            LOGGER.info("Captured %s of packets to %s.", format_size(file_size(file)), file)

    def report(self):
        LOGGER.debug("Analyzing the network capture...")
        started = time.monotonic()
        bitrates = Bitrates(self._streams, self._settings)
        for file in self.files:
            bitrates.add_file(file)
        report = bitrates.report()
        report.log()
        file = self._directory / f"{self._name}-bitrates.html"
        report.write_html(file)
        LOGGER.info(
            "Analyzed the network capture in %s.",
            format_timespan(round(time.monotonic() - started), max_units=2),
        )
        LOGGER.info("Open the bitrate graphs with 'open %s'.", file)

    def _start(self, interface: str):
        file = self._directory / f"{self._name}-{interface}.pcap"
        command = [
            "tcpdump",
            "-i",
            interface,
            "-s",
            str(SNAPSHOT_LENGTH),
            "-p",
            "-U",
            "-w",
            str(file),
            " or ".join(f"host {host}" for host in self._hosts),
        ]
        process = ManagedProcess(command, LOGGER)
        process.start()
        self._processes.append(process)
        self.files.append(file)
        wait_until(
            lambda: capture_is_started(process, file),
            f"the network capture on {interface} to start",
        )
        LOGGER.info("Capturing packets on %s to %s.", interface, file)


def capture_is_started(process: ManagedProcess, file: Path) -> bool:
    if not process.is_running():
        raise Exception(f"tcpdump exited. Is capturing to '{file}' allowed?")
    return file.exists()


def find_interface(host: str) -> str:
    output = subprocess.run(
        ["route", "-n", "get", host],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    match = re.search(r"^\s*interface:\s*(\S+)$", output, re.MULTILINE)
    if match is None:
        raise Exception(f"No network interface found for '{host}'.")
    return match.group(1)


def read_packets(file: Path):
    with file.open("rb") as fin:
        header = fin.read(24)
        if len(header) < 24:
            return
        endian, resolution = pcap_format(header)
        link_type = struct.unpack_from(f"{endian}I", header, 20)[0]
        record_header = struct.Struct(f"{endian}IIII")
        buffer = b""
        while True:
            chunk = fin.read(READ_SIZE)
            if not chunk:
                return
            buffer += chunk
            offset = 0
            length = len(buffer)
            view = memoryview(buffer)
            while offset + 16 <= length:
                seconds, fraction, captured_length, original_length = record_header.unpack_from(
                    buffer, offset
                )
                end = offset + 16 + captured_length
                if end > length:
                    break
                packet = parse_packet(link_type, view[offset + 16 : end])
                if packet is not None:
                    yield (seconds + fraction / resolution, *packet, original_length)
                offset = end
            buffer = buffer[offset:]


def pcap_format(header: bytes) -> tuple[str, float]:
    for endian in ["<", ">"]:
        magic = struct.unpack_from(f"{endian}I", header, 0)[0]
        if magic == PCAP_MAGIC_MICROSECONDS:
            return endian, 1e6
        if magic == PCAP_MAGIC_NANOSECONDS:
            return endian, 1e9
    raise Exception("Not a pcap file.")


def parse_packet(link_type: int, data: memoryview) -> tuple[Protocol, int, int] | None:
    if link_type == LINK_TYPE_ETHERNET:
        return parse_ethernet(data)
    if link_type == LINK_TYPE_NULL:
        return parse_loopback(data)
    raise Exception(f"Unsupported network capture link type {link_type}.")


def parse_ethernet(data: memoryview) -> tuple[Protocol, int, int] | None:
    if len(data) < 14:
        return None
    ethernet_type = struct.unpack_from(">H", data, 12)[0]
    offset = 14
    if ethernet_type == ETHERNET_TYPE_VLAN:
        ethernet_type, offset = struct.unpack_from(">H", data, 16)[0], 18
    if ethernet_type == ETHERNET_TYPE_IPV4:
        return parse_ip_v4(data, offset)
    if ethernet_type == ETHERNET_TYPE_IPV6:
        return parse_ip_v6(data, offset)
    return None


def parse_loopback(data: memoryview) -> tuple[Protocol, int, int] | None:
    if len(data) < 4:
        return None
    family = struct.unpack_from("=I", data, 0)[0]
    if family == NULL_FAMILY_IPV4:
        return parse_ip_v4(data, 4)
    if family == NULL_FAMILY_IPV6:
        return parse_ip_v6(data, 4)
    return None


def parse_ip_v4(data: memoryview, offset: int) -> tuple[Protocol, int, int] | None:
    if len(data) < offset + 20:
        return None
    protocol = PROTOCOLS.get(data[offset + 9])
    if protocol is None:
        return None
    if struct.unpack_from(">H", data, offset + 6)[0] & 0x1FFF:
        return None
    return parse_ports(protocol, data, offset + 4 * (data[offset] & 0x0F))


def parse_ip_v6(data: memoryview, offset: int) -> tuple[Protocol, int, int] | None:
    if len(data) < offset + 40:
        return None
    protocol = PROTOCOLS.get(data[offset + 6])
    if protocol is None:
        return None
    return parse_ports(protocol, data, offset + 40)


def parse_ports(protocol: Protocol, data: memoryview, offset: int) -> tuple[Protocol, int, int] | None:
    if len(data) < offset + 4:
        return None
    source_port, destination_port = struct.unpack_from(">HH", data, offset)
    return protocol, source_port, destination_port
