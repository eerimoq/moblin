import logging
import time
from collections import defaultdict
from dataclasses import dataclass
from dataclasses import field

from .ffmpeg import StreamRecorder
from .moblin import Moblin
from .moblin import parse_bitrate_status
from .moblin import parse_ingests_status
from .moblin import parse_uptime
from .utils import Range

LOGGER = logging.getLogger(__name__)


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

    def format(self, scale: float = 1) -> str:
        average = self.average()
        if self.minimum is None or self.maximum is None or average is None:
            return "-"
        values = [self.minimum, average, self.maximum]
        return " / ".join(format_value(value, scale, 1) for value in values)

    def __str__(self):
        return self.format()


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

    def __str__(self):
        if self.count == 0:
            return "never"
        return (
            f"{self.count} times, {self.total_duration:.0f} s in total, {self.longest_duration:.0f} s at most"
        )

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
class Counters:
    stream_reconnects: int = 0
    recorder_restarts: int = 0
    source_restarts: dict[str, float] = field(default_factory=dict)
    video_decode_errors: dict[str, float] = field(default_factory=dict)
    duplicated_video_buffers: dict[str, float] = field(default_factory=dict)
    dropped_video_buffers: dict[str, float] = field(default_factory=dict)
    failed_status_requests: int = 0
    thermal_states: defaultdict[str, float] = field(default_factory=lambda: defaultdict(float))


class Monitor:
    def __init__(
        self,
        moblin: Moblin,
        recorder: StreamRecorder | None,
        source_names: list[str],
        number_of_ingests: int,
        stream_enabled: bool,
        stream_bitrate_range: Range,
        ingests_bitrate_range: Range,
        traffic_shaping: str,
    ):
        self._moblin = moblin
        self._recorder = recorder
        self._number_of_ingests = number_of_ingests
        self._stream_enabled = stream_enabled
        self._stream_bitrate_range = stream_bitrate_range
        self._ingests_bitrate_range = ingests_bitrate_range
        self._traffic_shaping = traffic_shaping
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
        self._update_buffered_video_buffers()
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

    def _update_buffered_video_buffers(self):
        counts = self._moblin.buffered_video_buffers.counts()
        for name in sorted(set(counts.duplicated) | set(counts.dropped)):
            duplicated = counts.duplicated.get(name, 0)
            dropped = counts.dropped.get(name, 0)
            new_duplicated = duplicated - self.counters.duplicated_video_buffers.get(name, 0)
            new_dropped = dropped - self.counters.dropped_video_buffers.get(name, 0)
            if new_duplicated > 0 or new_dropped > 0:
                LOGGER.warning(
                    "Buffered video '%s' duplicated %d and dropped %d frames (%d and %d in total).",
                    name,
                    new_duplicated,
                    new_dropped,
                    duplicated,
                    dropped,
                )
        self.counters.duplicated_video_buffers = dict(counts.duplicated)
        self.counters.dropped_video_buffers = dict(counts.dropped)

    def source_restarted(self, name: str):
        self.counters.source_restarts[name] += 1
        LOGGER.warning("Ingest source '%s' died and was restarted.", name)

    def log_status(self):
        sample = self._previous_sample
        if sample is None:
            return
        LOGGER.info(
            "Status: %s. Monitored for %s.",
            "Live" if sample.is_live else "Not live",
            format_duration(sample.elapsed),
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
            "  Duplicated video frames: %s.",
            format_counts(self.counters.duplicated_video_buffers),
        )
        LOGGER.info(
            "  Dropped video frames: %s.",
            format_counts(self.counters.dropped_video_buffers),
        )

    def report(self):
        now = time.monotonic()
        self._update_video_decode_errors()
        self._update_buffered_video_buffers()
        for deviation in self._deviations:
            deviation.stop(now)
        counters = self.counters
        last = self._previous_sample
        LOGGER.info("--------------------- Stability report ---------------------")
        LOGGER.info("Duration:                   %s", format_duration(self.elapsed()))
        LOGGER.info(
            "Outgoing stream:            %s",
            "enabled" if self._stream_enabled else "disabled",
        )
        LOGGER.info("Traffic shaping:            %s", self._traffic_shaping)
        LOGGER.info(
            "Stream total in GB:         %s",
            format_gigabytes(last.stream_total_bytes if last else None),
        )
        LOGGER.info(
            "Ingests total in GB:        %s",
            format_gigabytes(last.ingests_total_bytes if last else None),
        )
        LOGGER.info(
            "Recorded stream in GB:      %s",
            format_gigabytes(last.received_total_bytes if last and self._recorder else None),
        )
        LOGGER.info("Minimum / average / maximum:")
        LOGGER.info("  Stream bitrate in Mbps:   %s", self.stream_bitrate.format(1e6))
        LOGGER.info("  Received bitrate in Mbps: %s", self.received_bitrate.format(1e6))
        LOGGER.info("  Ingests bitrate in Mbps:  %s", self.ingests_bitrate.format(1e6))
        LOGGER.info("  CPU in %%:                 %s", self.cpu_percent)
        LOGGER.info("  RAM in MB:                %s", self.ram_mb)
        LOGGER.info("RAM growth in MB:           %s", self._format_ram_growth())
        LOGGER.info("Stream reconnects:          %d", counters.stream_reconnects)
        LOGGER.info("Stream recorder restarts:   %d", counters.recorder_restarts)
        LOGGER.info("Ingest source restarts:     %s", format_counts(counters.source_restarts))
        LOGGER.info(
            "Video decode errors:        %s",
            format_counts(counters.video_decode_errors),
        )
        LOGGER.info(
            "Duplicated video frames:    %s",
            format_counts(counters.duplicated_video_buffers),
        )
        LOGGER.info(
            "Dropped video frames:       %s",
            format_counts(counters.dropped_video_buffers),
        )
        LOGGER.info("Failed status requests:     %d", counters.failed_status_requests)
        LOGGER.info("Recorded stream files:      %s", self._format_recorded_files())
        LOGGER.info("Thermal states in seconds:  %s", format_counts(counters.thermal_states))
        LOGGER.info("Deviations:")
        for deviation in self._deviations:
            LOGGER.info("  %-34s%s", f"{deviation.name}:", deviation)
        LOGGER.info("------------------------------------------------------------")

    def _add_deviation(self, name: str, timeout: float = 120) -> Deviation:
        deviation = Deviation(name, timeout)
        self._deviations.append(deviation)
        return deviation

    def _format_recorded_files(self) -> str:
        if self._recorder is None:
            return "-"
        return ", ".join(str(file) for file in self._recorder.files)

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
        if self._recorder is not None:
            self._read_recorder(sample)
        return sample

    def _read_recorder(self, sample: Sample):
        recorder = self._recorder
        if recorder is None:
            return
        sample.receiver_connected = recorder.is_running()
        sample.received_total_bytes = recorder.total_bytes()
        self.counters.recorder_restarts = recorder.restarts
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
        self._not_live.update(now, self._stream_enabled and not sample.is_live, "The app is not streaming")
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


def format_value(value: float | None, scale: float = 1, decimals: int = 0) -> str:
    if value is None:
        return "-"
    return f"{value / scale:.{decimals}f}"


def format_mbps(bitrate: float | None) -> str:
    return format_value(bitrate, 1e6, 1)


def format_gigabytes(total_bytes: float | None) -> str:
    return format_value(total_bytes, 1e9, 1)


def format_duration(seconds: float) -> str:
    hours, seconds = divmod(int(seconds), 3600)
    minutes, seconds = divmod(seconds, 60)
    return f"{hours}h {minutes:02d}m {seconds:02d}s"


def format_counts(counts: dict[str, float]) -> str:
    if not counts:
        return "-"
    return ", ".join(f"{name}: {value:.0f}" for name, value in sorted(counts.items()))
