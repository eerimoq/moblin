import logging
import time
from collections import defaultdict
from dataclasses import dataclass
from dataclasses import field

from humanfriendly import format_size
from humanfriendly import format_timespan
from systest_moblin.ffmpeg import StreamRecorder

from .moblin import BufferedBuffers
from .moblin import Moblin
from .moblin import parse_bitrate_status
from .moblin import parse_ingests_status
from .moblin import parse_uptime
from .traffic_shaper import Side
from .traffic_shaper import StreamStatistics
from .traffic_shaper import TrafficShaper
from .utils import Range

LOGGER = logging.getLogger(__name__)

REPORT_WIDTH = 64


class MonitorError(Exception):
    pass


class Statistics:
    def __init__(self):
        self.minimum: float | None = None
        self.maximum: float | None = None
        self._total = 0.0
        self._count = 0

    def add(self, value: float):
        if self.minimum is None or value < self.minimum:
            self.minimum = value
        if self.maximum is None or value > self.maximum:
            self.maximum = value
        self._total += value
        self._count += 1

    def average(self) -> float | None:
        if self._count == 0:
            return None
        return self._total / self._count

    def columns(self, scale: float = 1) -> list[str]:
        average = self.average()
        if self.minimum is None or self.maximum is None or average is None:
            return ["-", "-", "-"]
        values = [self.minimum, average, self.maximum]
        return [format_value(value, scale, 1) for value in values]


class Deviation:
    def __init__(self, name: str, timeout: float):
        self.name = name
        self.count = 0
        self.total_duration = 0.0
        self.longest_duration = 0.0
        self._timeout = timeout
        self._start_time: float | None = None

    def update(self, now: float, is_deviating: bool, message: str):
        if is_deviating:
            if self._start_time is None:
                self._start_time = now
                self.count += 1
                LOGGER.warning("%s: %s", self.name, message)
            duration = now - self._start_time
            if duration > self._timeout:
                raise MonitorError(f"{self.name} for {duration:.0f} seconds in a row: {message}")
        elif self._start_time is not None:
            duration = self._stop(now)
            LOGGER.info("%s: Back to normal after %.0f seconds.", self.name, duration)

    def stop(self, now: float):
        if self._start_time is not None:
            self._stop(now)

    def columns(self) -> list[str]:
        if self.count == 0:
            return ["0", "-", "-"]
        return [
            str(self.count),
            format_timespan(round(self.total_duration), max_units=2),
            format_timespan(round(self.longest_duration), max_units=2),
        ]

    def _stop(self, now: float) -> float:
        duration = now - (self._start_time or now)
        self.total_duration += duration
        self.longest_duration = max(self.longest_duration, duration)
        self._start_time = None
        return duration


@dataclass
class Sample:
    elapsed: float = 0
    is_live: bool = False
    stream_bitrate: float | None = None
    stream_total_bytes: float | None = None
    stream_uptime: float | None = None
    receiver_connected: bool = False
    received_bitrate: float | None = None
    received_total_bytes: float = 0
    ingests_bitrate: float = 0
    ingests_total_bytes: float = 0
    number_of_ingests: int = 0
    cpu_percent: float = 0
    ram_mb: float = 0
    battery_percent: int | None = None
    battery_charging: bool = False
    thermal_state: str = ""


@dataclass
class BufferedCounters:
    duplicated: dict[str, float] = field(default_factory=dict)
    dropped: dict[str, float] = field(default_factory=dict)


@dataclass
class Counters:
    stream_reconnects: int = 0
    source_restarts: dict[str, float] = field(default_factory=dict)
    video_decode_errors: dict[str, float] = field(default_factory=dict)
    buffered_video: BufferedCounters = field(default_factory=BufferedCounters)
    buffered_audio: BufferedCounters = field(default_factory=BufferedCounters)
    failed_status_requests: int = 0
    thermal_states: defaultdict[str, float] = field(default_factory=lambda: defaultdict(float))


class ShaperMonitor:
    def __init__(self, shaper: TrafficShaper):
        self._shaper = shaper
        self._latest: list[StreamStatistics] = []
        self._latest_time: float | None = None
        self._bitrates: defaultdict[tuple[str, Side], Statistics] = defaultdict(Statistics)
        self._latest_bitrates: dict[tuple[str, Side], float] = {}
        self._maximum_queued: defaultdict[str, float] = defaultdict(float)
        self._has_warned = False

    def poll(self):
        now = time.monotonic()
        try:
            statistics = self._shaper.statistics()
        except Exception as error:
            if not self._has_warned:
                LOGGER.warning("Failed to read the traffic shaper statistics. %s", error)
                self._has_warned = True
            return
        self._update(now, statistics)
        self._latest = statistics
        self._latest_time = now

    def log_status(self):
        if len(self._latest) == 0:
            return
        LOGGER.info("  Shaped streams in Mbps to device/tester: %s.", self._format_bitrates())
        LOGGER.info("  Shaped streams dropped/queued: %s.", self._format_queues())

    def queue_rows(self) -> list[list[str]]:
        return [
            [
                stream.name,
                format_value(stream.queue.dropped),
                format_value(stream.queue.overlimits),
                format_value(self._maximum_queued[stream.name]),
            ]
            for stream in self._latest
        ]

    def bitrate_rows(self) -> list[list[str]]:
        rows = []
        for stream in self._latest:
            for side, traffic in stream.sent.items():
                rows.append(
                    [
                        f"{stream.name} to {side}",
                        *self._bitrates[(stream.name, side)].columns(1e6),
                        format_size(traffic.total_bytes),
                    ]
                )
        return rows

    def _format_bitrates(self) -> str:
        parts = []
        for stream in self._latest:
            to_device = self._latest_bitrates.get((stream.name, Side.DEVICE))
            to_tester = self._latest_bitrates.get((stream.name, Side.TESTER))
            parts.append(f"{stream.name}: {format_mbps(to_device)}/{format_mbps(to_tester)}")
        return ", ".join(parts)

    def _format_queues(self) -> str:
        return ", ".join(
            f"{stream.name}: {stream.queue.dropped:.0f}/{stream.queue.backlog_packets:.0f}"
            for stream in self._latest
        )

    def _update(self, now: float, statistics: list[StreamStatistics]):
        for stream in statistics:
            self._maximum_queued[stream.name] = max(
                self._maximum_queued[stream.name], stream.queue.backlog_packets
            )
        elapsed = now - (self._latest_time or now)
        if elapsed <= 0:
            return
        previous_streams = {stream.name: stream for stream in self._latest}
        for stream in statistics:
            previous_stream = previous_streams.get(stream.name)
            if previous_stream is None:
                continue
            self._update_bitrates(stream, previous_stream, elapsed)

    def _update_bitrates(self, stream: StreamStatistics, previous: StreamStatistics, elapsed: float):
        for side, traffic in stream.sent.items():
            previous_traffic = previous.sent.get(side)
            if previous_traffic is None:
                continue
            bitrate = bits_per_second(traffic.total_bytes - previous_traffic.total_bytes, elapsed)
            self._bitrates[(stream.name, side)].add(bitrate)
            self._latest_bitrates[(stream.name, side)] = bitrate


class Monitor:
    def __init__(
        self,
        moblin: Moblin,
        stream_recorder: StreamRecorder | None,
        source_names: list[str],
        number_of_ingests: int,
        stream_bitrate_range: Range,
        ingests_bitrate_range: Range,
        duration: float,
        shaper: TrafficShaper | None,
    ):
        self._moblin = moblin
        self._stream_recorder = stream_recorder
        self._number_of_ingests = number_of_ingests
        self._stream_bitrate_range = stream_bitrate_range
        self._ingests_bitrate_range = ingests_bitrate_range
        self._duration = duration
        self._traffic_shaping = "none" if shaper is None else shaper.description()
        self._shaper_monitor = None if shaper is None else ShaperMonitor(shaper)
        self._start_time = time.monotonic()
        self._next_log_time = time.monotonic()
        self._previous_poll_time: float | None = None
        self._previous_sample: Sample | None = None
        self.counters = Counters(source_restarts={name: 0 for name in source_names})
        self.stream_bitrate = Statistics()
        self.received_bitrate = Statistics()
        self.ingests_bitrate = Statistics()
        self.cpu_percent = Statistics()
        self.ram_mb = Statistics()
        self.first_ram_mb: float | None = None
        self.last_ram_mb: float | None = None
        self._deviations: list[Deviation] = []
        self._unreachable = self._add_deviation("App unreachable", 60)
        self._not_live = self._add_deviation("Not live")
        self._stream_bitrate_deviation = self._add_deviation("Stream bitrate out of range")
        self._receiver_deviation = self._add_deviation("Stream not recorded to disk")
        self._ingests_deviation = self._add_deviation("Wrong number of ingests")
        self._ingests_bitrate_deviation = self._add_deviation("Ingests bitrate out of range")

    def elapsed(self) -> float:
        return time.monotonic() - self._start_time

    def poll(self):
        now = time.monotonic()
        self._update_video_decode_errors()
        self._update_buffered_buffers()
        if self._shaper_monitor is not None:
            self._shaper_monitor.poll()
        try:
            status = self._moblin.get_status()
        except Exception as error:
            self.counters.failed_status_requests += 1
            self._unreachable.update(now, True, str(error))
            return
        self._unreachable.update(now, False, "")
        sample = self._create_sample(status)
        self._update_statistics(sample)
        self._update_counters(sample, now)
        self._previous_sample = sample
        self._previous_poll_time = now
        self._check(now, sample)
        if time.monotonic() >= self._next_log_time:
            self.log_status()
            self._next_log_time += 60

    def _update_video_decode_errors(self):
        counts = self._moblin.video_decode_errors.counts()
        for name, count in sorted(counts.items()):
            new_errors = count - self.counters.video_decode_errors.get(name, 0)
            if new_errors > 0:
                LOGGER.warning(
                    "Video decoder '%s' failed to decode %d frames (%d in total).",
                    name,
                    new_errors,
                    count,
                )
        self.counters.video_decode_errors = dict(counts)

    def _update_buffered_buffers(self):
        self._update_buffered_media_buffers(
            "Buffered video", self._moblin.buffered_video_buffers, self.counters.buffered_video
        )
        self._update_buffered_media_buffers(
            "Buffered audio", self._moblin.buffered_audio_buffers, self.counters.buffered_audio
        )

    def _update_buffered_media_buffers(
        self, title: str, buffers: BufferedBuffers, counters: BufferedCounters
    ):
        counts = buffers.counts()
        for name in sorted(set(counts.duplicated) | set(counts.dropped)):
            duplicated = counts.duplicated.get(name, 0)
            dropped = counts.dropped.get(name, 0)
            new_duplicated = duplicated - counters.duplicated.get(name, 0)
            new_dropped = dropped - counters.dropped.get(name, 0)
            if new_duplicated > 0 or new_dropped > 0:
                LOGGER.warning(
                    "%s '%s' duplicated %d and dropped %d buffers (%d and %d in total).",
                    title,
                    name,
                    new_duplicated,
                    new_dropped,
                    duplicated,
                    dropped,
                )
        counters.duplicated = dict(counts.duplicated)
        counters.dropped = dict(counts.dropped)

    def source_restarted(self, name: str):
        self.counters.source_restarts[name] += 1
        LOGGER.warning("Ingest source '%s' died and was restarted.", name)

    def log_status(self):
        sample = self._previous_sample
        if sample is None:
            return
        LOGGER.info(
            "Status: %s. Monitored for %s. Remaining %s.",
            "Live" if sample.is_live else "Not live",
            format_timespan(round(sample.elapsed), max_units=2),
            format_timespan(round(max(self._duration - sample.elapsed, 0)), max_units=2),
        )
        LOGGER.info(
            "  Stream: %s Mbps (%s Mbps received). Ingests: %s Mbps (%d).",
            format_mbps(sample.stream_bitrate),
            format_mbps(sample.received_bitrate),
            format_mbps(sample.ingests_bitrate),
            sample.number_of_ingests,
        )
        LOGGER.info(
            "  CPU: %s %%. RAM: %s MB. Battery: %s %%%s. Thermal state: %s.",
            format_value(sample.cpu_percent),
            format_value(sample.ram_mb),
            format_value(sample.battery_percent),
            " (charging)" if sample.battery_charging else "",
            sample.thermal_state or "-",
        )
        LOGGER.info(
            "  Ingest source restarts: %s.",
            format_counts(self.counters.source_restarts),
        )
        LOGGER.info(
            "  Video decode errors: %s.",
            format_counts(self.counters.video_decode_errors),
        )
        LOGGER.info(
            "  Duplicated video buffers: %s.",
            format_counts(self.counters.buffered_video.duplicated),
        )
        LOGGER.info(
            "  Dropped video buffers: %s.",
            format_counts(self.counters.buffered_video.dropped),
        )
        LOGGER.info(
            "  Duplicated audio buffers: %s.",
            format_counts(self.counters.buffered_audio.duplicated),
        )
        LOGGER.info(
            "  Dropped audio buffers: %s.",
            format_counts(self.counters.buffered_audio.dropped),
        )
        if self._shaper_monitor is not None:
            self._shaper_monitor.log_status()

    def report(self):
        now = time.monotonic()
        self._update_video_decode_errors()
        self._update_buffered_buffers()
        for deviation in self._deviations:
            deviation.stop(now)
        counters = self.counters
        last = self._previous_sample
        log_heading("Stability report")
        log_items(
            [
                ("Duration", format_timespan(round(self.elapsed()))),
                ("Traffic shaping", self._traffic_shaping),
                ("Stream reconnects", str(counters.stream_reconnects)),
                ("Failed status requests", str(counters.failed_status_requests)),
                ("RAM growth in MB", self._format_ram_growth()),
            ]
        )
        log_table(
            "Transferred",
            ["Total"],
            [
                ["Stream", format_total_bytes(last.stream_total_bytes if last else None)],
                ["Ingests", format_total_bytes(last.ingests_total_bytes if last else None)],
                [
                    "Recorded stream",
                    format_total_bytes(last.received_total_bytes if last and self._stream_recorder else None),
                ],
            ],
        )
        log_table(
            "Measurements",
            ["Minimum", "Average", "Maximum"],
            [
                ["Stream bitrate in Mbps", *self.stream_bitrate.columns(1e6)],
                ["Received bitrate in Mbps", *self.received_bitrate.columns(1e6)],
                ["Ingests bitrate in Mbps", *self.ingests_bitrate.columns(1e6)],
                ["CPU in %", *self.cpu_percent.columns()],
                ["RAM in MB", *self.ram_mb.columns()],
            ],
        )
        if self._shaper_monitor is not None:
            log_table(
                "Shaped stream queues",
                ["Dropped", "Overlimits", "Queued"],
                self._shaper_monitor.queue_rows(),
            )
            log_table(
                "Shaped streams in Mbps",
                ["Minimum", "Average", "Maximum", "Total"],
                self._shaper_monitor.bitrate_rows(),
            )
        log_table("Ingest sources", ["Restarts"], count_rows(counters.source_restarts))
        log_table("Video decoders", ["Errors"], count_rows(counters.video_decode_errors))
        log_table("Buffered video", ["Duplicated", "Dropped"], buffered_rows(counters.buffered_video))
        log_table("Buffered audio", ["Duplicated", "Dropped"], buffered_rows(counters.buffered_audio))
        log_table(
            "Thermal states",
            ["Duration"],
            [
                [name or "-", format_timespan(round(seconds), max_units=2)]
                for name, seconds in sorted(counters.thermal_states.items())
            ],
        )
        log_table(
            "Deviations",
            ["Times", "In total", "At most"],
            [[deviation.name, *deviation.columns()] for deviation in self._deviations],
        )
        log_rule()

    def _add_deviation(self, name: str, timeout: float = 120) -> Deviation:
        deviation = Deviation(name, timeout)
        self._deviations.append(deviation)
        return deviation

    def _format_recorded_file(self) -> str:
        if self._stream_recorder is None:
            return "-"
        return str(self._stream_recorder.file)

    def _format_ram_growth(self) -> str:
        if self.first_ram_mb is None or self.last_ram_mb is None:
            return "-"
        return f"{self.last_ram_mb - self.first_ram_mb:+.0f}"

    def _create_sample(self, status) -> Sample:
        general = status.get("general") or {}
        top_right = status.get("topRight") or {}
        cpu_percent, ram_mb = parse_system_monitor(get_message(top_right, "systemMonitor"))
        sample = Sample(
            elapsed=self.elapsed(),
            is_live=bool(general.get("isLive")),
            battery_percent=general.get("batteryLevel"),
            battery_charging=bool(general.get("batteryCharging")),
            thermal_state=general.get("flame") or "",
            cpu_percent=cpu_percent,
            ram_mb=ram_mb,
        )
        bitrate = parse_bitrate_status(get_message(top_right, "bitrate"))
        if bitrate is not None:
            sample.stream_bitrate = bitrate.bitrate
            sample.stream_total_bytes = bitrate.total_bytes
        sample.stream_uptime = parse_uptime(get_message(top_right, "uptime"))
        ingests = parse_ingests_status(get_message(top_right, "rtmpServer") or "0")
        sample.ingests_bitrate = ingests.bitrate
        sample.ingests_total_bytes = ingests.total_bytes
        sample.number_of_ingests = ingests.number_of_ingests
        if self._stream_recorder is not None:
            self._read_recorder(sample)
        return sample

    def _read_recorder(self, sample: Sample):
        recorder = self._stream_recorder
        if recorder is None:
            return
        sample.receiver_connected = recorder.is_running()
        sample.received_total_bytes = recorder.total_bytes()
        previous = self._previous_sample
        if previous is None:
            return
        elapsed = sample.elapsed - previous.elapsed
        if elapsed > 0:
            sample.received_bitrate = (
                8 * (sample.received_total_bytes - previous.received_total_bytes) / elapsed
            )

    def _update_statistics(self, sample: Sample):
        if sample.is_live and sample.stream_bitrate is not None:
            self.stream_bitrate.add(sample.stream_bitrate)
        if sample.received_bitrate is not None:
            self.received_bitrate.add(sample.received_bitrate)
        self.ingests_bitrate.add(sample.ingests_bitrate)
        self.cpu_percent.add(sample.cpu_percent)
        self.ram_mb.add(sample.ram_mb)
        if self.first_ram_mb is None:
            self.first_ram_mb = sample.ram_mb
        self.last_ram_mb = sample.ram_mb

    def _update_counters(self, sample: Sample, now: float):
        if self._previous_poll_time is not None:
            self.counters.thermal_states[sample.thermal_state] += now - self._previous_poll_time
        previous_sample = self._previous_sample
        if previous_sample is None:
            return
        if is_reconnect(previous_sample.stream_uptime, sample.stream_uptime):
            self.counters.stream_reconnects += 1
            LOGGER.warning("The outgoing stream reconnected.")
        if previous_sample.battery_charging and not sample.battery_charging:
            LOGGER.warning("The device is no longer charging.")

    def _check(self, now: float, sample: Sample):
        self._not_live.update(
            now, self._stream_recorder is not None and not sample.is_live, "The app is not streaming"
        )
        self._stream_bitrate_deviation.update(
            now,
            sample.is_live
            and not is_within(
                sample.stream_bitrate,
                self._stream_bitrate_range.minimum,
                self._stream_bitrate_range.maximum,
            ),
            f"{format_mbps(sample.stream_bitrate)} Mbps",
        )
        self._receiver_deviation.update(
            now,
            sample.is_live and (not sample.receiver_connected or sample.received_bitrate == 0),
            "No stream recorder" if not sample.receiver_connected else "No data received",
        )
        self._ingests_deviation.update(
            now,
            sample.number_of_ingests != self._number_of_ingests,
            f"{sample.number_of_ingests} instead of {self._number_of_ingests}",
        )
        self._ingests_bitrate_deviation.update(
            now,
            not is_within(
                sample.ingests_bitrate,
                self._ingests_bitrate_range.minimum,
                self._ingests_bitrate_range.maximum,
            ),
            f"{format_mbps(sample.ingests_bitrate)} Mbps",
        )
        self._check_battery(sample)

    def _check_battery(self, sample: Sample):
        level = sample.battery_percent
        if sample.battery_charging or level is None:
            return
        if 0 < level < 10:
            raise MonitorError(
                f"The device battery level is {level} %. Connect the device to power and run the test again."
            )


def buffered_rows(counters: BufferedCounters) -> list[list[str]]:
    return [
        [name, format_value(counters.duplicated.get(name, 0)), format_value(counters.dropped.get(name, 0))]
        for name in sorted(set(counters.duplicated) | set(counters.dropped))
    ]


def count_rows(counts: dict[str, float]) -> list[list[str]]:
    return [[name, format_value(count)] for name, count in sorted(counts.items())]


def log_heading(title: str):
    LOGGER.info("")
    LOGGER.info("%s", f" {title} ".center(REPORT_WIDTH, "="))


def log_rule():
    LOGGER.info("%s", REPORT_WIDTH * "=")
    LOGGER.info("")


def log_items(items: list[tuple[str, str]]):
    width = max(len(name) for name, _ in items) + 3
    for name, value in items:
        LOGGER.info("%s%s", name.ljust(width), value)


def log_table(title: str, headers: list[str], rows: list[list[str]]):
    LOGGER.info("")
    if not rows:
        LOGGER.info("%s", title)
        LOGGER.info("  -")
        return
    name_width = max([len(title)] + [len(row[0]) + 2 for row in rows]) + 3
    widths = [
        max([len(header)] + [len(row[index + 1]) for row in rows]) + 3 for index, header in enumerate(headers)
    ]
    LOGGER.info("%s%s", title.ljust(name_width), columns_to_string(headers, widths))
    for row in rows:
        LOGGER.info("%s%s", f"  {row[0]}".ljust(name_width), columns_to_string(row[1:], widths))


def columns_to_string(columns: list[str], widths: list[int]) -> str:
    return "".join(column.rjust(width) for column, width in zip(columns, widths))


def get_message(status, name: str) -> str:
    item = status.get(name)
    if item is None:
        return ""
    return item.get("message", "")


def parse_system_monitor(message: str) -> tuple[float, float]:
    parts = message.split()
    if len(parts) != 3:
        raise MonitorError(f"Failed to parse system monitor: {message}")
    cpu_percent = float(parts[0].rstrip("%").replace(",", "."))
    ram_mb = float(parts[1].replace(",", "."))
    return cpu_percent, ram_mb


def is_reconnect(previous: float | None, current: float | None) -> bool:
    if previous is None:
        return False
    return current is None or current < previous


def is_within(value: float | None, minimum: float, maximum: float) -> bool:
    if value is None:
        return False
    return minimum <= value <= maximum


def bits_per_second(total_bytes: float, elapsed: float) -> float:
    return 8 * total_bytes / elapsed


def format_value(value: float | None, scale: float = 1, decimals: int = 0) -> str:
    if value is None:
        return "-"
    return f"{value / scale:.{decimals}f}"


def format_mbps(bitrate: float | None) -> str:
    return format_value(bitrate, 1e6, 1)


def format_total_bytes(total_bytes: float | None) -> str:
    if total_bytes is None:
        return "-"
    return format_size(total_bytes)


def format_counts(counts: dict[str, float]) -> str:
    if not counts:
        return "-"
    return ", ".join(f"{name}: {value:.0f}" for name, value in sorted(counts.items()))
