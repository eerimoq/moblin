import json
import logging
import statistics
from dataclasses import dataclass
from datetime import datetime
from datetime import timedelta
from pathlib import Path

from .common.ffmpeg import VideoTimecode
from .common.ffmpeg import ffprobe_format
from .common.ffmpeg import read_video_timecodes
from .common.utils import anchor_time_of_day
from .utils import slope_per_hour

LOGGER = logging.getLogger(__name__)

WINDOW_DURATION = 20.0
FIRST_WINDOW_START = 60.0
MAXIMUM_TIMECODE_ERROR = 60.0
TIMECODE_TOLERANCE = 1.0
TEMPLATE_FILE = Path(__file__).parent / "timecodes.html"


@dataclass
class TimecodeWindow:
    time: float
    points: list[tuple[float, float]]

    def offset(self) -> float:
        return statistics.median(offset for _, offset in self.points)


@dataclass
class TimecodeReport:
    path: Path
    start: datetime
    windows: list[TimecodeWindow]
    frames: int
    missing: int
    outside: int

    def spread(self) -> float:
        if len(self.windows) == 0:
            return 0.0
        offsets = [window.offset() for window in self.windows]
        return max(offsets) - min(offsets)

    def drift(self) -> float:
        return slope_per_hour([(window.time, window.offset()) for window in self.windows])

    def span(self) -> float:
        if len(self.windows) == 0:
            return 0.0
        return self.windows[-1].time - self.windows[0].time

    def log(self):
        LOGGER.debug("SEI timecodes in %s", self.path)
        for window in self.windows:
            LOGGER.debug(
                "  At %.0f s: timecode %.0f ms ahead of the stream (%s seconds ticks)",
                window.time,
                1000 * window.offset(),
                len(window.points),
            )
        LOGGER.debug(
            "  %s of %s frames have a usable timecode (%s do not match the wall clock, "
            "spread %.0f ms, drift %.0f ms/h).",
            self.frames - self.missing - self.outside,
            self.frames,
            self.outside,
            1000 * self.spread(),
            1000 * self.drift(),
        )


def measure_timecodes(path: Path, start: datetime, number_of_windows: int) -> TimecodeReport:
    probe = ffprobe_format(path)
    windows = []
    frames = 0
    missing = 0
    outside = 0
    for window_time in _window_times(probe.duration, number_of_windows):
        timecodes = read_video_timecodes(path, probe.start_time + window_time, WINDOW_DURATION)
        frames += len(timecodes)
        missing += sum(1 for timecode in timecodes if timecode is None)
        ticks = _ticks(timecodes, start, probe.start_time)
        points = _seconds_tick_points(ticks)
        if len(points) == 0:
            continue
        window = TimecodeWindow(window_time, points)
        outside += sum(1 for _, _, offset in ticks if _is_outside(offset, window.offset()))
        windows.append(window)
    return TimecodeReport(path, start, windows, frames, missing, outside)


def write_timecodes_html(output: Path, report: TimecodeReport, settings: dict[str, str]):
    data = {
        "startTime": report.start.astimezone().strftime("%Y-%m-%d %H:%M:%S"),
        "file": report.path.name,
        "frames": report.frames,
        "missing": report.missing,
        "outside": report.outside,
        "settings": [{"name": name, "value": value} for name, value in settings.items()],
        "points": [
            [round(time, 3), round(1000 * offset, 3)]
            for window in report.windows
            for time, offset in window.points
        ],
        "medians": [[round(window.time, 3), round(1000 * window.offset(), 3)] for window in report.windows],
    }
    template = TEMPLATE_FILE.read_text()
    output.write_text(template.replace('"__TIMECODES_DATA__"', json.dumps(data)))


def _ticks(
    timecodes: list[VideoTimecode | None],
    start: datetime,
    start_time: float,
) -> list[tuple[float, float, float]]:
    ticks = []
    for timecode in timecodes:
        if timecode is None:
            continue
        expected = start + timedelta(seconds=timecode.pts - start_time)
        second = anchor_time_of_day(timecode.second_of_day(), expected)
        ticks.append((timecode.pts - start_time, second, second - expected.timestamp()))
    return ticks


def _seconds_tick_points(ticks: list[tuple[float, float, float]]) -> list[tuple[float, float]]:
    points = []
    previous_second = None
    for time, second, offset in ticks:
        if previous_second is not None and second != previous_second:
            points.append((time, offset))
        previous_second = second
    return points


def _is_outside(offset: float, window_offset: float) -> bool:
    if abs(offset) > MAXIMUM_TIMECODE_ERROR:
        return True
    return not window_offset - 1 - TIMECODE_TOLERANCE < offset <= window_offset + TIMECODE_TOLERANCE


def _window_times(duration: float, number_of_windows: int) -> list[float]:
    first = min(FIRST_WINDOW_START, max(duration - WINDOW_DURATION, 0))
    last = max(duration - WINDOW_DURATION, first)
    count = min(number_of_windows, int((last - first) / WINDOW_DURATION) + 1)
    if count < 2:
        return [first]
    step = (last - first) / (count - 1)
    return [first + step * index for index in range(count)]
