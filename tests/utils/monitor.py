import logging
import shutil
import time
from collections import defaultdict
from dataclasses import dataclass
from dataclasses import field
from pathlib import Path

from .ffmpeg import StreamContent
from .ffmpeg import capture_stream_content
from .mediamtx import MediaMtx
from .moblin import Moblin
from .moblin import parse_bitrate_status
from .moblin import parse_ingests_status
from .moblin import parse_uptime
from .utils import Range

LOGGER = logging.getLogger(__name__)
STREAM_CONTENT_MINIMUM_DURATION_RATIO = 0.8


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
                raise MonitorError(
                    f"{self.name} for {duration:.0f} seconds in a row: {message}"
                )
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
            f"{self.count} times, {self.total_duration:.0f} s in total, "
            f"{self.longest_duration:.0f} s at most"
        )

    def _stop(self, now: float) -> float:
        duration = now - (self._start_time or now)
        self.total_duration += duration
        self.longest_duration = max(self.longest_duration, duration)
        self._start_time = None
        return duration


@dataclass
class StreamContentExpectation:
    url: str
    path: Path
    width: int
    height: int
    fps: float
    interval: float = 300
    duration: float = 10
    minimum_mean_volume_db: float = -45
    minimum_unique_video_frames_ratio: float = 0.5
    minimum_fps_ratio: float = 0.8
    maximum_fps_ratio: float = 1.2


def check_stream_content(
    content: StreamContent, expectation: StreamContentExpectation
) -> list[str]:
    problems = []
    if content.duration < STREAM_CONTENT_MINIMUM_DURATION_RATIO * expectation.duration:
        problems.append(
            f"Captured {content.duration:.1f} instead of "
            f"{expectation.duration:.1f} seconds"
        )
    problems += _check_stream_content_video(content, expectation)
    problems += _check_stream_content_audio(content, expectation)
    return problems


def _check_stream_content_video(
    content: StreamContent, expectation: StreamContentExpectation
) -> list[str]:
    if not content.has_video():
        return ["No video in the stream"]
    problems = []
    if (content.width, content.height) != (expectation.width, expectation.height):
        problems.append(
            f"The video is {content.width}x{content.height} instead of "
            f"{expectation.width}x{expectation.height}"
        )
    minimum_duration = 0.5 * expectation.duration
    if content.video_duration < minimum_duration:
        problems.append(
            f"Only {content.video_duration:.1f} of {expectation.duration:.1f} "
            "seconds contain video"
        )
    fps = content.video_fps()
    if not is_within(
        fps,
        expectation.minimum_fps_ratio * expectation.fps,
        expectation.maximum_fps_ratio * expectation.fps,
    ):
        problems.append(f"The video is {fps:.1f} instead of {expectation.fps:.1f} fps")
    ratio = content.unique_video_frames_ratio()
    if ratio < expectation.minimum_unique_video_frames_ratio:
        problems.append(
            f"The video looks frozen. Only {content.unique_video_frames} of "
            f"{content.video_frames} frames differ from the frame before them"
        )
    return problems


def _check_stream_content_audio(
    content: StreamContent, expectation: StreamContentExpectation
) -> list[str]:
    if not content.has_audio():
        return ["No audio in the stream"]
    problems = []
    minimum_duration = STREAM_CONTENT_MINIMUM_DURATION_RATIO * expectation.duration
    if content.audio_duration < minimum_duration:
        problems.append(
            f"Only {content.audio_duration:.1f} of {expectation.duration:.1f} "
            "seconds contain audio"
        )
    if content.mean_volume_db < expectation.minimum_mean_volume_db:
        problems.append(
            f"The audio is silent. Its mean volume is {content.mean_volume_db:.1f} dB"
        )
    return problems


class StreamContentChecker:
    def __init__(self, expectation: StreamContentExpectation):
        self._expectation = expectation
        self._next_time = time.monotonic()
        self._saved_captures = 0
        self.checks = 0
        self.failed_checks = 0
        self.video_fps = Statistics()
        self.mean_volume_db = Statistics()

    def is_due(self, now: float) -> bool:
        return now >= self._next_time

    def check(self, now: float) -> list[str]:
        self._next_time = now + self._expectation.interval
        self.checks += 1
        try:
            content = capture_stream_content(
                self._expectation.url,
                self._expectation.duration,
                self._expectation.path,
            )
        except Exception as error:
            problems = [f"Failed to capture the stream: {error}"]
        else:
            problems = check_stream_content(content, self._expectation)
            self._update_statistics(content)
            self._log(content)
        if len(problems) > 0:
            self.failed_checks += 1
            self._save_capture()
        return problems

    def _update_statistics(self, content: StreamContent):
        self.video_fps.add(content.video_fps())
        self.mean_volume_db.add(content.mean_volume_db)

    def _log(self, content: StreamContent):
        LOGGER.info(
            "Stream content: %.1f s of %s %dx%d at %.1f fps with %.0f %% moving "
            "frames. %.1f s of %s %d Hz %d channels at %.1f dB.",
            content.video_duration,
            content.video_codec or "-",
            content.width,
            content.height,
            content.video_fps(),
            100 * content.unique_video_frames_ratio(),
            content.audio_duration,
            content.audio_codec or "-",
            content.sample_rate,
            content.channels,
            content.mean_volume_db,
        )

    def _save_capture(self):
        path = self._expectation.path
        if self._saved_captures >= 5:
            return
        if not path.exists():
            return
        self._saved_captures += 1
        saved_path = path.with_name(
            f"{path.stem}-{self._saved_captures}{path.suffix}",
        )
        shutil.copyfile(path, saved_path)
        LOGGER.warning("Saved the unexpected stream content to %s.", saved_path)


@dataclass
class Sample:
    elapsed: float = 0
    is_live: bool = False
    stream_bitrate: float | None = None
    stream_total_bytes: float | None = None
    stream_uptime: float | None = None
    receiver_connected: bool = False
    received_bitrate: float | None = None
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
    receiver_reconnects: int = 0
    source_restarts: dict[str, float] = field(default_factory=dict)
    video_decode_errors: dict[str, float] = field(default_factory=dict)
    duplicated_video_buffers: dict[str, float] = field(default_factory=dict)
    dropped_video_buffers: dict[str, float] = field(default_factory=dict)
    failed_status_requests: int = 0
    thermal_states: defaultdict[str, float] = field(
        default_factory=lambda: defaultdict(float)
    )


class Monitor:
    def __init__(
        self,
        moblin: Moblin,
        mediamtx: MediaMtx,
        stream_path: str,
        source_names: list[str],
        number_of_ingests: int,
        stream_bitrate_range: Range,
        ingests_bitrate_range: Range,
        stream_content: StreamContentExpectation,
        traffic_shaping: str,
    ):
        self._moblin = moblin
        self._mediamtx = mediamtx
        self._stream_path = stream_path
        self._number_of_ingests = number_of_ingests
        self._stream_bitrate_range = stream_bitrate_range
        self._ingests_bitrate_range = ingests_bitrate_range
        self._traffic_shaping = traffic_shaping
        self._start_time = time.monotonic()
        self._next_log_time = time.monotonic()
        self._previous_poll_time: float | None = None
        self._previous_sample: Sample | None = None
        self._previous_publisher: tuple[str, int] | None = None
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
        self._stream_bitrate_deviation = self._add_deviation(
            "Stream bitrate out of range"
        )
        self._receiver_deviation = self._add_deviation(
            "Stream not received by MediaMTX"
        )
        self._ingests_deviation = self._add_deviation("Wrong number of ingests")
        self._ingests_bitrate_deviation = self._add_deviation(
            "Ingests bitrate out of range"
        )
        self._stream_content_checker = StreamContentChecker(stream_content)
        self._stream_content_deviation = self._add_deviation(
            "Unexpected stream content",
            0.5 * stream_content.interval,
        )

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
        self._check_stream_content(now, sample)
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
            new_duplicated = duplicated - self.counters.duplicated_video_buffers.get(
                name, 0
            )
            new_dropped = dropped - self.counters.dropped_video_buffers.get(name, 0)
            if new_duplicated > 0 or new_dropped > 0:
                LOGGER.warning(
                    "Buffered video '%s' duplicated %d and dropped %d frames "
                    "(%d and %d in total).",
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
        LOGGER.info("Traffic shaping:            %s", self._traffic_shaping)
        LOGGER.info(
            "Stream total in GB:         %s",
            format_gigabytes(last.stream_total_bytes if last else None),
        )
        LOGGER.info(
            "Ingests total in GB:        %s",
            format_gigabytes(last.ingests_total_bytes if last else None),
        )
        LOGGER.info("Minimum / average / maximum:")
        LOGGER.info("  Stream bitrate in Mbps:   %s", self.stream_bitrate.format(1e6))
        LOGGER.info("  Received bitrate in Mbps: %s", self.received_bitrate.format(1e6))
        LOGGER.info("  Ingests bitrate in Mbps:  %s", self.ingests_bitrate.format(1e6))
        LOGGER.info("  CPU in %%:                 %s", self.cpu_percent)
        LOGGER.info("  RAM in MB:                %s", self.ram_mb)
        LOGGER.info(
            "  Received video FPS:       %s", self._stream_content_checker.video_fps
        )
        LOGGER.info(
            "  Received audio in dB:     %s",
            self._stream_content_checker.mean_volume_db,
        )
        LOGGER.info("RAM growth in MB:           %s", self._format_ram_growth())
        LOGGER.info("Stream reconnects:          %d", counters.stream_reconnects)
        LOGGER.info("Receiver reconnects:        %d", counters.receiver_reconnects)
        LOGGER.info(
            "Ingest source restarts:     %s", format_counts(counters.source_restarts)
        )
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
        LOGGER.info(
            "Stream content checks:      %d (%d failed)",
            self._stream_content_checker.checks,
            self._stream_content_checker.failed_checks,
        )
        LOGGER.info(
            "Thermal states in seconds:  %s", format_counts(counters.thermal_states)
        )
        LOGGER.info("Deviations:")
        for deviation in self._deviations:
            LOGGER.info("  %-34s%s", f"{deviation.name}:", deviation)
        LOGGER.info("------------------------------------------------------------")

    def _add_deviation(self, name: str, timeout: float = 120) -> Deviation:
        deviation = Deviation(name, timeout)
        self._deviations.append(deviation)
        return deviation

    def _format_ram_growth(self) -> str:
        if self.first_ram_mb is None or self.last_ram_mb is None:
            return "-"
        return f"{self.last_ram_mb - self.first_ram_mb:+.0f}"

    def _create_sample(self, status) -> Sample:
        general = status.get("general") or {}
        top_right = status.get("topRight") or {}
        cpu_percent, ram_mb = parse_system_monitor(
            get_message(top_right, "systemMonitor")
        )
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
        self._read_publisher(sample)
        return sample

    def _read_publisher(self, sample: Sample):
        try:
            publisher = self._mediamtx.get_srt_publisher(self._stream_path)
        except Exception as error:
            LOGGER.warning("Failed to read the MediaMTX status: %s", error)
            return
        if publisher is None:
            self._previous_publisher = None
            return
        sample.receiver_connected = True
        previous = self._previous_publisher
        self._previous_publisher = publisher
        if previous is None or self._previous_sample is None:
            return
        if previous[0] != publisher[0]:
            self.counters.receiver_reconnects += 1
            LOGGER.warning("MediaMTX accepted a new SRT connection from the app.")
            return
        elapsed = sample.elapsed - self._previous_sample.elapsed
        if elapsed > 0:
            sample.received_bitrate = 8 * (publisher[1] - previous[1]) / elapsed

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
            self.counters.thermal_states[sample.thermal_state] += (
                now - self._previous_poll_time
            )
        previous_sample = self._previous_sample
        if previous_sample is None:
            return
        if is_reconnect(previous_sample.stream_uptime, sample.stream_uptime):
            self.counters.stream_reconnects += 1
            LOGGER.warning("The outgoing stream reconnected.")
        if previous_sample.battery_charging and not sample.battery_charging:
            LOGGER.warning("The device is no longer charging.")

    def _check(self, now: float, sample: Sample):
        self._not_live.update(now, not sample.is_live, "The app is not streaming")
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
            sample.is_live
            and (not sample.receiver_connected or sample.received_bitrate == 0),
            "No SRT publisher" if not sample.receiver_connected else "No data received",
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

    def _check_stream_content(self, now: float, sample: Sample):
        if not sample.is_live or not self._stream_content_checker.is_due(now):
            return
        problems = self._stream_content_checker.check(now)
        self._stream_content_deviation.update(
            now, len(problems) > 0, ". ".join(problems)
        )

    def _check_battery(self, sample: Sample):
        level = sample.battery_percent
        if sample.battery_charging or level is None:
            return
        if 0 < level < 10:
            raise MonitorError(
                f"The device battery level is {level} %. Connect the device to power "
                "and run the test again."
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
