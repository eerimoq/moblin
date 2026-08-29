import bisect
import logging
import statistics
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from .common.ffmpeg import AudioBandLevel
from .common.ffmpeg import Crop
from .common.ffmpeg import Pixel
from .common.ffmpeg import detect_audio_onsets
from .common.ffmpeg import ffmpeg_run
from .common.ffmpeg import ffprobe_format
from .common.ffmpeg import ffprobe_video_size
from .common.ffmpeg import measure_audio_band_levels
from .common.ffmpeg import read_video_region_colors
from .generate_device_settings import WidgetType
from .generate_device_settings import uuid
from .utils import FILES_DIR
from .utils import slope_per_hour

LOGGER = logging.getLogger(__name__)

ALERT_COMMAND_NAME = "sync"
ALERT_IMAGE_ID = uuid()
ALERT_SOUND_ID = uuid()
ALERT_IMAGE_FILE = FILES_DIR / "alert-sync.gif"
ALERT_SOUND_FILE = FILES_DIR / "alert-sync.wav"
ALERT_IMAGE_SIZE = 240
ALERT_IMAGE_INSET = 20
ALERT_IMAGE_DURATION = 2
ALERT_QUADRANT_COLORS = [
    Pixel(255, 0, 255),
    Pixel(0, 255, 0),
    Pixel(0, 0, 255),
    Pixel(255, 255, 0),
]
ALERT_COLOR_TOLERANCE = 60
ALERT_SOUND_FREQUENCY = 3000
ALERT_SOUND_BANDWIDTH = 150
ALERT_SOUND_BANDPASS_STAGES = 3
ALERT_SOUND_DURATION = 0.4
ALERT_SOUND_LEVEL_MARGIN = 12
ALERT_SOUND_FLOOR_MARGIN = 30
ALERT_SOUND_WINDOW = 0.1
AUDIO_SEARCH_MARGIN = 10.0
MAXIMUM_ALERT_OFFSET = 1.5
VIDEO_SEARCH_MARGIN = 3.0


def alert_media_files() -> dict[str, Path]:
    _create_alert_image()
    _create_alert_sound()
    return {
        f"Alerts/{ALERT_IMAGE_ID}": ALERT_IMAGE_FILE,
        f"Alerts/{ALERT_SOUND_ID}": ALERT_SOUND_FILE,
    }


def alerts_widget_settings(name: str, widget_id: str):
    return {
        "id": widget_id,
        "name": name,
        "type": WidgetType.ALERTS,
        "enabled": True,
        "alerts": {
            "chatBot": {
                "commands": [
                    {
                        "name": ALERT_COMMAND_NAME,
                        "alert": {
                            "enabled": True,
                            "imageId": ALERT_IMAGE_ID,
                            "imageLoopCount": 1,
                            "soundId": ALERT_SOUND_ID,
                            "textToSpeechEnabled": False,
                        },
                    }
                ]
            }
        },
    }


def alerts_media_gallery_settings():
    return {
        "bundledImages": [],
        "customImages": [{"id": ALERT_IMAGE_ID, "name": "Sync"}],
        "bundledSounds": [],
        "customSounds": [{"id": ALERT_SOUND_ID, "name": "Sync"}],
    }


def alert_chat_message() -> str:
    return f"!moblin alert {ALERT_COMMAND_NAME}"


def alert_crop(width: int, height: int, x: float, y: float) -> Crop:
    return Crop(
        x=round(x * width / 100) + ALERT_IMAGE_INSET,
        y=round(y * height / 100) + ALERT_IMAGE_INSET,
        width=ALERT_IMAGE_SIZE - 2 * ALERT_IMAGE_INSET,
        height=ALERT_IMAGE_SIZE - 2 * ALERT_IMAGE_INSET,
    )


@dataclass
class AlertSync:
    index: int
    trigger_time: float
    audio_time: float
    video_time: float

    def offset(self) -> float:
        return self.audio_time - self.video_time


@dataclass
class AlertSyncReport:
    path: Path
    alerts: list[AlertSync]
    missing: list[int]

    def offsets(self) -> list[float]:
        return [alert.offset() for alert in self.alerts]

    def spread(self) -> float:
        offsets = self.offsets()
        return max(offsets) - min(offsets)

    def drift(self) -> float:
        return slope_per_hour([(alert.trigger_time, alert.offset()) for alert in self.alerts])

    def log(self):
        LOGGER.debug("Alert audio and video synchronization in %s", self.path)
        for alert in self.alerts:
            LOGGER.debug(
                "  Alert %s: video at %.3f s, audio at %.3f s, audio is %.0f ms late",
                alert.index,
                alert.video_time,
                alert.audio_time,
                1000 * alert.offset(),
            )
        if len(self.missing) > 0:
            LOGGER.debug("  Alerts not found: %s", ", ".join(str(index) for index in self.missing))
        if len(self.alerts) == 0:
            return
        offsets = self.offsets()
        LOGGER.debug(
            "  Found %s of %s alerts. Audio is %.0f to %.0f ms late (spread %.0f ms, drift %.0f ms/h).",
            len(self.alerts),
            len(self.alerts) + len(self.missing),
            1000 * min(offsets),
            1000 * max(offsets),
            1000 * self.spread(),
            1000 * self.drift(),
        )


def measure_alert_synchronization(
    path: Path,
    trigger_times: list[float],
    x: float,
    y: float,
) -> AlertSyncReport:
    width, height = ffprobe_video_size(path)
    crop = alert_crop(width, height, x, y)
    audio_times = _find_audio_onsets(path, trigger_times)
    with ThreadPoolExecutor(max_workers=8) as executor:
        video_times = list(
            executor.map(lambda audio_time: _find_video_onset(path, crop, audio_time), audio_times)
        )
    alerts = []
    missing = []
    for index, (trigger_time, audio_time, video_time) in enumerate(
        zip(trigger_times, audio_times, video_times)
    ):
        if audio_time is None or video_time is None:
            missing.append(index)
        elif abs(audio_time - video_time) > MAXIMUM_ALERT_OFFSET:
            missing.append(index)
        else:
            alerts.append(AlertSync(index, trigger_time, audio_time, video_time))
    return AlertSyncReport(path, alerts, missing)


def _find_audio_onsets(path: Path, trigger_times: list[float]) -> list[float | None]:
    probe = ffprobe_format(path)
    onsets = []
    for alert_sound in _find_alert_sounds(path, probe.start_time):
        if alert_sound.time > probe.duration - ALERT_SOUND_DURATION:
            continue
        onset = _refine_alert_sound(path, alert_sound, probe.start_time)
        if onset is not None:
            onsets.append(onset)
    return _match_onsets(onsets, trigger_times)


@dataclass
class AlertSound:
    time: float
    level: float


def _alert_sound_filters() -> list[str]:
    return ALERT_SOUND_BANDPASS_STAGES * [
        f"bandpass=f={ALERT_SOUND_FREQUENCY}:width_type=h:w={ALERT_SOUND_BANDWIDTH}"
    ]


def _find_alert_sounds(path: Path, start_time: float) -> list[AlertSound]:
    levels = measure_audio_band_levels(
        path,
        _alert_sound_filters(),
        ALERT_SOUND_WINDOW,
        copy_timestamps=True,
    )
    if len(levels) == 0:
        return []
    threshold = statistics.median(level.level for level in levels) + ALERT_SOUND_FLOOR_MARGIN
    alert_sounds = []
    run: list[AudioBandLevel] = []
    for level in levels:
        if level.level > threshold:
            run.append(level)
            continue
        alert_sounds += _alert_sound(run, start_time)
        run = []
    return alert_sounds + _alert_sound(run, start_time)


def _alert_sound(run: list[AudioBandLevel], start_time: float) -> list[AlertSound]:
    if len(run) * ALERT_SOUND_WINDOW < ALERT_SOUND_DURATION / 2:
        return []
    return [AlertSound(run[0].time - start_time, max(level.level for level in run))]


def _refine_alert_sound(path: Path, alert_sound: AlertSound, start_time: float) -> float | None:
    onsets = detect_audio_onsets(
        path,
        alert_sound.level - ALERT_SOUND_LEVEL_MARGIN,
        ALERT_SOUND_DURATION,
        _alert_sound_filters(),
        copy_timestamps=True,
        start=max(alert_sound.time - 1, 0),
        duration=1 + 2 * ALERT_SOUND_DURATION,
    )
    onsets = [
        onset - start_time
        for onset in sorted(onsets)
        if abs(onset - start_time - alert_sound.time) < ALERT_SOUND_WINDOW + ALERT_SOUND_DURATION / 2
    ]
    if len(onsets) == 0:
        return None
    return onsets[0]


def _match_onsets(onsets: list[float], trigger_times: list[float]) -> list[float | None]:
    onsets = sorted(onsets)
    best: list[float | None] = [None] * len(trigger_times)
    best_score = (0, 0.0)
    for onset in onsets:
        for trigger_time in trigger_times:
            offset = onset - trigger_time
            matched = _match_onsets_with_offset(onsets, trigger_times, offset)
            score = _score_onsets(matched, trigger_times, offset)
            if score > best_score:
                best_score = score
                best = matched
    return best


def _score_onsets(
    matched: list[float | None],
    trigger_times: list[float],
    offset: float,
) -> tuple[int, float]:
    matches = 0
    error = 0.0
    for trigger_time, onset in zip(trigger_times, matched):
        if onset is None:
            continue
        matches += 1
        error += abs(onset - (trigger_time + offset))
    return matches, -error


def _match_onsets_with_offset(
    onsets: list[float],
    trigger_times: list[float],
    offset: float,
) -> list[float | None]:
    matched: list[float | None] = []
    for trigger_time in trigger_times:
        nearest = _nearest(onsets, trigger_time + offset)
        if nearest is None or abs(nearest - (trigger_time + offset)) > AUDIO_SEARCH_MARGIN:
            matched.append(None)
        else:
            matched.append(nearest)
    return matched


def _nearest(values: list[float], value: float) -> float | None:
    index = bisect.bisect_left(values, value)
    candidates = values[max(index - 1, 0) : index + 1]
    if len(candidates) == 0:
        return None
    return min(candidates, key=lambda candidate: abs(candidate - value))


def _find_video_onset(path: Path, crop: Crop, audio_time: float | None) -> float | None:
    if audio_time is None:
        return None
    frames = read_video_region_colors(
        path,
        crop,
        2,
        2,
        max(audio_time - VIDEO_SEARCH_MARGIN, 0),
        2 * VIDEO_SEARCH_MARGIN,
    )
    for frame in frames:
        if _is_alert_image(frame.colors):
            return frame.pts
    return None


def _is_alert_image(colors: list[Pixel]) -> bool:
    if len(colors) != len(ALERT_QUADRANT_COLORS):
        return False
    return all(_is_color(color, expected) for color, expected in zip(colors, ALERT_QUADRANT_COLORS))


def _is_color(color: Pixel, expected: Pixel) -> bool:
    return (
        abs(color.red - expected.red) <= ALERT_COLOR_TOLERANCE
        and abs(color.green - expected.green) <= ALERT_COLOR_TOLERANCE
        and abs(color.blue - expected.blue) <= ALERT_COLOR_TOLERANCE
    )


def _create_alert_image():
    if ALERT_IMAGE_FILE.exists():
        return
    half = ALERT_IMAGE_SIZE // 2
    positions = [(0, 0), (half, 0), (0, half), (half, half)]
    boxes = "".join(
        f",drawbox=x={x}:y={y}:w={half}:h={half}"
        f":color=0x{color.red:02X}{color.green:02X}{color.blue:02X}:t=fill"
        for (x, y), color in zip(positions, ALERT_QUADRANT_COLORS)
    )
    ffmpeg_run(
        "-filter_complex",
        f"color=c=black:s={ALERT_IMAGE_SIZE}x{ALERT_IMAGE_SIZE}:r=10:d={ALERT_IMAGE_DURATION}{boxes},"
        "split[image][sample];"
        "[sample]palettegen=max_colors=8[palette];"
        "[image][palette]paletteuse=dither=none[out]",
        "-map",
        "[out]",
        "-loop",
        "0",
        str(ALERT_IMAGE_FILE),
    )


def _create_alert_sound():
    if ALERT_SOUND_FILE.exists():
        return
    ffmpeg_run(
        "-f",
        "lavfi",
        "-i",
        f"sine=frequency={ALERT_SOUND_FREQUENCY}:sample_rate=48000:duration={ALERT_SOUND_DURATION}",
        "-c:a",
        "pcm_s16le",
        "-ac",
        "1",
        str(ALERT_SOUND_FILE),
    )
