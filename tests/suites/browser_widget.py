import functools
import logging
import math
import time
from pathlib import Path
from urllib.parse import unquote

from systest_moblin.ffmpeg import BEEP_BANDWIDTH
from systest_moblin.ffmpeg import BEEP_DURATION
from systest_moblin.ffmpeg import BEEP_FREQUENCY
from systest_moblin.ffmpeg import BEEP_INTERVAL
from systest_moblin.ffmpeg import BEEP_LEVEL_MARGIN
from systest_moblin.ffmpeg import Crop
from systest_moblin.ffmpeg import FfmpegVideoCodec
from systest_moblin.ffmpeg import QrCode
from systest_moblin.ffmpeg import create_qr_codes_video
from systest_moblin.ffmpeg import detect_audio_onsets
from systest_moblin.ffmpeg import detect_beeps
from systest_moblin.ffmpeg import ffmpeg_run
from systest_moblin.ffmpeg import ffprobe_format
from systest_moblin.ffmpeg import measure_max_volume
from systest_moblin.ffmpeg import read_qr_codes
from systest_moblin.ffmpeg import video_encoder_args

from ..utils.config import HTTP_PROXY_PORT
from ..utils.config import WEB_SERVER_PORT
from ..utils.config import Capability
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import BrowserMode
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import browser_widget_settings
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.http_server import HttpServer
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import WEBSITES_DIR
from ..utils.utils import create_qr_code_image
from ..utils.utils import manual_volume_requirement

LOGGER = logging.getLogger(__name__)
PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID = uuid()
AUDIO_AND_VIDEO_ONLY_WIDGET_ID = uuid()
AUDIO_ONLY_WIDGET_ID = uuid()
LOCAL_ONLY_WIDGET_ID = uuid()
PAGE_WIDGET_ID = uuid()
QR_CODE_IMAGE = WEBSITES_DIR / "BrowserWidgetHighFpsVideo.jpg"
QR_CODES_VIDEO = WEBSITES_DIR / "BrowserWidgetHighFpsVideo.mp4"
BEEPS_AUDIO = WEBSITES_DIR / "BrowserWidgetBeeps.mp4"
BEEPS_VIDEO = WEBSITES_DIR / "BrowserWidgetBeepsVideo.mp4"
LONG_BEEPS_VIDEO = WEBSITES_DIR / "BrowserWidgetLongBeepsVideo.mp4"
LOW_BEEPS_VIDEO = WEBSITES_DIR / "BrowserWidgetLowBeepsVideo.mp4"
SHORT_BEEPS_VIDEO = WEBSITES_DIR / "BrowserWidgetShortBeepsVideo.mp4"
LOW_BEEP_FREQUENCY = 1200
FIRST_WIDGET_ID = uuid()
SECOND_WIDGET_ID = uuid()
SAME_PAGE_WIDGET_ID = uuid()
MINIMUM_NUMBER_OF_BEEPS = 3


def beeps_source(frequency: int = BEEP_FREQUENCY) -> str:
    return (
        f"aevalsrc=exprs='if(lt(mod(t,{BEEP_INTERVAL}),{BEEP_DURATION}),"
        f"0.5*sin(2*PI*{frequency}*t),0)':s=48000"
    )


def create_beeps_audio(path: Path, duration: int, frequency: int = BEEP_FREQUENCY):
    ffmpeg_run("-f", "lavfi", "-t", str(duration), "-i", beeps_source(frequency), "-c:a", "aac", str(path))


def create_beeps_video(path: Path, duration: int, text: str, frequency: int = BEEP_FREQUENCY):
    ffmpeg_run(
        "-f",
        "lavfi",
        "-t",
        str(duration),
        "-i",
        "testsrc2=size=640x360:rate=30",
        "-f",
        "lavfi",
        "-t",
        str(duration),
        "-i",
        beeps_source(frequency),
        "-vf",
        f"drawtext=fontsize=60:fontcolor=white:box=1:boxcolor=black:text='{text} %{{pts\\:hms}}':x=10:y=10",
        *video_encoder_args(1_000_000, FfmpegVideoCodec.H264, False),
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        str(path),
    )


@functools.cache
def create_media():
    create_qr_code_image("n 1 pts 999.0", QR_CODE_IMAGE)
    create_qr_codes_video(QR_CODES_VIDEO)
    create_beeps_audio(BEEPS_AUDIO, 12)
    create_beeps_video(LONG_BEEPS_VIDEO, 15, "Long")
    create_beeps_video(LOW_BEEPS_VIDEO, 5, "Low", LOW_BEEP_FREQUENCY)
    create_beeps_video(SHORT_BEEPS_VIDEO, 5, "Short")
    ffmpeg_run(
        "-i",
        str(QR_CODES_VIDEO),
        "-f",
        "lavfi",
        "-t",
        "10",
        "-i",
        beeps_source(),
        "-c:v",
        "copy",
        "-c:a",
        "aac",
        "-shortest",
        str(BEEPS_VIDEO),
    )


def detect_beeps_at_frequency(path: Path, frequency: int) -> list[float]:
    audio_filters = [f"bandpass=f={frequency}:width_type=h:w={BEEP_BANDWIDTH}"]
    max_volume = measure_max_volume(path, audio_filters)
    if max_volume == -math.inf:
        return []
    onsets = detect_audio_onsets(path, max_volume - BEEP_LEVEL_MARGIN, 2 * BEEP_DURATION, audio_filters)
    end_of_file = ffprobe_format(path).duration - BEEP_DURATION
    return [onset for onset in onsets if onset < end_of_file]


def find_beep_series(beeps: list[float], count: int) -> float | None:
    for start in beeps:
        aligned = [
            beep
            for beep in beeps
            if beep >= start
            and abs(beep - start - BEEP_INTERVAL * round((beep - start) / BEEP_INTERVAL)) < 0.1
        ]
        if len(aligned) >= count:
            return start
    return None


def page_url(server: HttpServer, page: str) -> str:
    return server.url(f"/BrowserWidget{page}.html?{uuid()}")


def page_reports(request_counts: dict[str, int], reporter: str) -> list[str]:
    prefix = f"/report/{reporter}/"
    return [unquote(path.removeprefix(prefix)) for path in request_counts if path.startswith(prefix)]


def log_reports(request_counts: dict[str, int]):
    for path in request_counts:
        if path.startswith("/report/"):
            LOGGER.debug("Report: %s", unquote(path))


def qr_code_crop(x: int, y: int) -> Crop:
    return Crop(x=x, y=y, width=400, height=400)


class BrowserWidgetTestCase(TestCase):
    def assert_qr_codes_found(self, qr_codes: list[QrCode]):
        self.assert_greater(len(qr_codes), 0)
        for index, qr_code in enumerate(qr_codes):
            self.assert_not_equal(qr_code.number, -1, f"Index {index}")

    def assert_some_qr_codes_found(self, qr_codes: list[QrCode]):
        self.assert_true(any(qr_code.number != -1 for qr_code in qr_codes))

    def assert_no_qr_codes_found(self, qr_codes: list[QrCode]):
        for index, qr_code in enumerate(qr_codes):
            self.assert_equal(qr_code.number, -1, f"Index {index}")

    def assert_started_playing(self, request_counts: dict[str, int], reporter: str, name: str):
        reports = page_reports(request_counts, reporter)
        self.assert_true(any(report.startswith(f"{name}playing") for report in reports), f"{reporter} {name}")

    def assert_not_started_playing(self, request_counts: dict[str, int], reporter: str, name: str):
        reports = page_reports(request_counts, reporter)
        self.assert_false(
            any(report.startswith(f"{name}playing") for report in reports), f"{reporter} {name}"
        )

    def assert_high_fps_qr_codes_found(self, qr_codes: list[QrCode]):
        self.assert_greater(len(qr_codes), 0)
        previous_frame_number = qr_codes[0].number
        seen_frame_number_count = 1
        for index, qr_code in enumerate(qr_codes[1:]):
            if qr_code.number == previous_frame_number:
                seen_frame_number_count += 1
                LOGGER.debug(
                    "Duplicated browser widget frame found at index %s (seen %s times)",
                    index,
                    seen_frame_number_count,
                )
            else:
                seen_frame_number_count = 1
            self.assert_greater_equal(qr_code.number, previous_frame_number, f"Index {index}")
            self.assert_less(seen_frame_number_count, 4, f"Index {index}")
            previous_frame_number = qr_code.number

    def assert_first_beeps_after_second_beeps(self, recording_file: Path):
        first_beeps = detect_beeps_at_frequency(recording_file, BEEP_FREQUENCY)
        second_beeps = detect_beeps_at_frequency(recording_file, LOW_BEEP_FREQUENCY)
        LOGGER.debug("First widget beeps at %s.", ", ".join(f"{beep:.3f} s" for beep in first_beeps))
        LOGGER.debug("Second widget beeps at %s.", ", ".join(f"{beep:.3f} s" for beep in second_beeps))
        second_start = find_beep_series(second_beeps, 3)
        if second_start is None:
            raise Exception("No second widget beeps found.")
        second_end = second_start + 2 * BEEP_INTERVAL
        first_beeps_after = [beep for beep in first_beeps if beep > second_end + 1]
        self.assert_is_not_none(
            find_beep_series(first_beeps_after, 2), "First widget beeps after second widget."
        )


class BrowserWidgetModes(BrowserWidgetTestCase):
    """4 browser widgets; one for each mode and one local only."""

    def import_settings(self, url: str):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": [
                            scene_widget_settings(PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID, 0, 0, 100),
                            scene_widget_settings(AUDIO_AND_VIDEO_ONLY_WIDGET_ID, 50, 0, 100),
                            scene_widget_settings(AUDIO_ONLY_WIDGET_ID, 0, 50, 100),
                            scene_widget_settings(LOCAL_ONLY_WIDGET_ID, 50, 50, 100),
                        ],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    browser_widget_settings(
                        "Browser periodic audio and video",
                        PERIODIC_AUDIO_AND_VIDEO_WIDGET_ID,
                        url,
                        mode=BrowserMode.PERIODIC_AUDIO_AND_VIDEO,
                    ),
                    browser_widget_settings(
                        "Browser audio and video only",
                        AUDIO_AND_VIDEO_ONLY_WIDGET_ID,
                        url,
                        mode=BrowserMode.AUDIO_AND_VIDEO_ONLY,
                    ),
                    browser_widget_settings(
                        "Browser audio only",
                        AUDIO_ONLY_WIDGET_ID,
                        url,
                        mode=BrowserMode.AUDIO_ONLY,
                    ),
                    browser_widget_settings(
                        "Browser local only",
                        LOCAL_ONLY_WIDGET_ID,
                        url,
                        localOnly=True,
                    ),
                ],
            }
        )

    def run(self):
        create_media()
        with HttpServer(WEB_SERVER_PORT, WEBSITES_DIR, self.moblin.config.tester_ip_address()) as server:
            self.import_settings(page_url(server, "HighFpsVideo"))
            recording_file = self.moblin.record(16, "BrowserWidgetHighFpsVideo.mp4")
        self.assert_image_qr_codes_periodic_audio_and_video(recording_file)
        self.assert_video_qr_codes_periodic_audio_and_video(recording_file)
        self.assert_image_qr_codes_audio_and_video_only(recording_file)
        self.assert_video_qr_codes_audio_and_video_only(recording_file)
        self.assert_image_qr_codes_audio_only(recording_file)
        self.assert_video_qr_codes_audio_only(recording_file)
        self.assert_image_qr_codes_local_only(recording_file)
        self.assert_video_qr_codes_local_only(recording_file)

    def assert_image_qr_codes_periodic_audio_and_video(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(0, 0))
        self.assert_qr_codes_found(qr_codes)

    def assert_video_qr_codes_periodic_audio_and_video(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(400, 0))
        self.assert_high_fps_qr_codes_found(qr_codes[180:380])

    def assert_image_qr_codes_audio_and_video_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(960, 0))
        self.assert_no_qr_codes_found(qr_codes[:100])
        self.assert_qr_codes_found(qr_codes[180:380])
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_video_qr_codes_audio_and_video_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(960 + 400, 0))
        self.assert_no_qr_codes_found(qr_codes[:100])
        self.assert_high_fps_qr_codes_found(qr_codes[180:380])
        self.assert_no_qr_codes_found(qr_codes[450:])

    def assert_image_qr_codes_audio_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(0, 540))
        self.assert_no_qr_codes_found(qr_codes)

    def assert_video_qr_codes_audio_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(400, 540))
        self.assert_no_qr_codes_found(qr_codes)

    def assert_image_qr_codes_local_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(960, 540))
        self.assert_no_qr_codes_found(qr_codes)

    def assert_video_qr_codes_local_only(self, recording_file: Path):
        qr_codes = read_qr_codes(recording_file, qr_code_crop(960 + 400, 540))
        self.assert_no_qr_codes_found(qr_codes)


class BrowserWidgetPageTestCase(BrowserWidgetTestCase):
    def record_page(self, page: str, duration: float, reporters: list[str], **browser) -> Path:
        create_media()
        with HttpServer(WEB_SERVER_PORT, WEBSITES_DIR, self.moblin.config.tester_ip_address()) as server:
            self.import_settings(page_url(server, page), **browser)
            recording_file = self.moblin.record(duration, f"BrowserWidget{page}.mp4")
            request_counts = server.request_counts()
        for reporter in reporters:
            self.assert_reported_ok(request_counts, reporter)
        return recording_file

    def import_settings(self, url: str, **browser):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": [scene_widget_settings(PAGE_WIDGET_ID, 0, 0, 100)],
                        "enabled": True,
                    }
                ],
                "widgets": [browser_widget_settings("Browser", PAGE_WIDGET_ID, url, **browser)],
            }
        )

    def assert_reported_ok(self, request_counts: dict[str, int], reporter: str):
        reports = page_reports(request_counts, reporter)
        for report in reports:
            LOGGER.debug("%s reported '%s'.", reporter, report)
        self.assert_equal([report for report in reports if report != "ok"], [], reporter)
        self.assert_in("ok", reports, reporter)

    def assert_beeps(self, recording_file: Path):
        beeps = detect_beeps(recording_file)
        LOGGER.debug(
            "Found %s beeps in %s at %s.",
            len(beeps),
            recording_file,
            ", ".join(f"{beep:.3f} s" for beep in beeps),
        )
        self.assert_greater_equal(len(beeps), MINIMUM_NUMBER_OF_BEEPS)


class BrowserWidgetStatic(BrowserWidgetPageTestCase):
    """Overlay without video; an image, a canvas drawn in animation frames and a CSS background."""

    def run(self):
        recording_file = self.record_page("Static", 10, ["Static"])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(480, 0))[90:])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(960, 0))[90:])


class BrowserWidgetScriptTiming(BrowserWidgetPageTestCase):
    """Scripts run in order at document start and end, with a style sheet shown late content."""

    def run(self):
        recording_file = self.record_page(
            "ScriptTiming",
            12,
            ["ScriptTiming"],
            styleSheet=".overlay { display: block; }",
        )
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(480, 0))[240:])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(960, 0))[90:])


class BrowserWidgetGlobalNames(BrowserWidgetPageTestCase):
    """Page declaring a global const named log, which Moblin's injected script also uses."""

    def run(self):
        recording_file = self.record_page("GlobalNames", 10, ["GlobalNames"])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:])


class BrowserWidgetFlexLayout(BrowserWidgetPageTestCase):
    """Flexbox body layout with a paused video must not be moved by injected elements."""

    def run(self):
        recording_file = self.record_page("FlexLayout", 10, ["FlexLayout"])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(1520, 0))[90:])


class BrowserWidgetVideoAlert(BrowserWidgetPageTestCase):
    """Alert card with a video, added after 4 seconds and removed when ended."""

    def run(self):
        recording_file = self.record_page("VideoAlert", 16, ["VideoAlert"])
        qr_codes = read_qr_codes(recording_file, qr_code_crop(40, 40))
        self.assert_high_fps_qr_codes_found(qr_codes[180:330])


class BrowserWidgetBodyReplace(BrowserWidgetPageTestCase):
    """Video alerts replacing all body children, removing Moblin's injected canvas, without errors."""

    def run(self):
        recording_file = self.record_page("BodyReplace", 16, ["BodyReplace"])
        first_qr_codes = read_qr_codes(recording_file, qr_code_crop(0, 0))
        self.assert_some_qr_codes_found(first_qr_codes)
        self.assert_no_qr_codes_found(first_qr_codes[420:])
        second_qr_codes = read_qr_codes(recording_file, qr_code_crop(960, 0))
        self.assert_high_fps_qr_codes_found(second_qr_codes[300:390])


class BrowserWidgetHiddenVideo(BrowserWidgetPageTestCase):
    """Playing videos that are not displayed must not be shown."""

    def run(self):
        recording_file = self.record_page("HiddenVideo", 16, ["HiddenVideo"])
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[150:420])
        self.assert_no_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(1440, 0)))


class BrowserWidgetIframe(BrowserWidgetPageTestCase):
    """Video playing in an iframe."""

    def run(self):
        recording_file = self.record_page("Iframe", 16, ["Iframe", "IframeVideo"])
        qr_codes = read_qr_codes(recording_file, qr_code_crop(480, 240))
        self.assert_high_fps_qr_codes_found(qr_codes[90:200])


class BrowserWidgetLog(BrowserWidgetPageTestCase):
    """Page writing to Moblin's log with moblin.log()."""

    def run(self):
        log_entries: list[str] = []
        self.moblin.add_log_entry_observer(log_entries.append)
        try:
            self.record_page("Log", 5, ["Log"], moblinAccess=True)
        finally:
            self.moblin.remove_log_entry_observer(log_entries.append)
        expected = "browser-effect-server: Log Hello from a browser widget!"
        self.assert_true(any(expected in entry for entry in log_entries), expected)


class BrowserWidgetReloadAfterFailedLoadTestCase(BrowserWidgetPageTestCase):
    def reload_after_failed_load(self, overrides: dict):
        create_media()
        ip_address = self.moblin.config.tester_ip_address()
        url = f"http://{ip_address}:{WEB_SERVER_PORT}/BrowserWidgetStatic.html?{uuid()}"
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": [scene_widget_settings(PAGE_WIDGET_ID, 0, 0, 100)],
                        "enabled": True,
                    }
                ],
                "widgets": [browser_widget_settings("Browser", PAGE_WIDGET_ID, url)],
                **overrides,
            }
        )
        time.sleep(5)
        with HttpServer(WEB_SERVER_PORT, WEBSITES_DIR, ip_address) as server:
            time.sleep(5)
            self.assert_equal(page_reports(server.request_counts(), "Static"), [])
            self.moblin.reload_browser_widgets()
            recording_file = self.moblin.record(10, f"{type(self).__name__}.mp4")
            request_counts = server.request_counts()
        self.assert_reported_ok(request_counts, "Static")
        self.assert_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:])


class BrowserWidgetReloadAfterFailedLoad(BrowserWidgetReloadAfterFailedLoadTestCase):
    """Reload browser widgets loads a page whose first load failed as its web server was down."""

    def run(self):
        self.reload_after_failed_load({})


class BrowserWidgetReloadAfterFailedLoadHttpProxy(BrowserWidgetReloadAfterFailedLoadTestCase):
    """Reload browser widgets loads a page whose first load through the HTTP proxy failed."""

    def run(self):
        self.reload_after_failed_load(
            {"httpProxy": {"enabled": True, "localNetwork": True, "port": HTTP_PROXY_PORT}}
        )


class BrowserWidgetAudioElement(BrowserWidgetPageTestCase):
    """Beeps played by an audio element through the speaker."""

    def run(self):
        manual_volume_requirement(LOGGER)
        recording_file = self.record_page("AudioElement", 10, ["AudioElement"])
        self.assert_beeps(recording_file)


class BrowserWidgetAudioLate(BrowserWidgetPageTestCase):
    """Beeps played by an audio object created from a timer through the speaker."""

    def run(self):
        manual_volume_requirement(LOGGER)
        recording_file = self.record_page("AudioLate", 10, ["AudioLate"])
        self.assert_beeps(recording_file)


class BrowserWidgetVideoSound(BrowserWidgetPageTestCase):
    """Beeps played by an unmuted video through the speaker, with the video shown."""

    def run(self):
        manual_volume_requirement(LOGGER)
        recording_file = self.record_page("VideoSound", 10, ["VideoSound"])
        self.assert_beeps(recording_file)
        self.assert_high_fps_qr_codes_found(read_qr_codes(recording_file, qr_code_crop(0, 0))[90:200])


class BrowserWidgetWebAudio(BrowserWidgetPageTestCase):
    """Beeps played by Web Audio oscillators through the speaker."""

    def run(self):
        manual_volume_requirement(LOGGER)
        recording_file = self.record_page("WebAudio", 10, ["WebAudio"])
        self.assert_beeps(recording_file)


class BrowserWidgetConcurrentAudioTestCase(BrowserWidgetTestCase):
    def import_settings(self, first_url: str, second_url: str):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": [
                            scene_widget_settings(FIRST_WIDGET_ID, 0, 0, 50),
                            scene_widget_settings(SECOND_WIDGET_ID, 50, 0, 50),
                        ],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    browser_widget_settings("Browser first", FIRST_WIDGET_ID, first_url),
                    browser_widget_settings("Browser second", SECOND_WIDGET_ID, second_url),
                ],
            }
        )

    def record_pages(self, first_page: str) -> tuple[Path, dict[str, int]]:
        manual_volume_requirement(LOGGER)
        create_media()
        with HttpServer(WEB_SERVER_PORT, WEBSITES_DIR, self.moblin.config.tester_ip_address()) as server:
            self.import_settings(
                page_url(server, first_page),
                page_url(server, "ConcurrentAudioSecond"),
            )
            recording_file = self.moblin.record(20, f"BrowserWidget{first_page}.mp4")
            request_counts = server.request_counts()
        log_reports(request_counts)
        self.assert_started_playing(request_counts, first_page, "interrupted ")
        self.assert_started_playing(request_counts, "ConcurrentAudioSecond", "")
        return recording_file, request_counts


class BrowserWidgetConcurrentAudio(BrowserWidgetConcurrentAudioTestCase):
    """Two widgets playing audio; autoplay of new audio in the first never starts after being interrupted."""

    def run(self):
        _, request_counts = self.record_pages("ConcurrentAudioFirst")
        self.assert_not_started_playing(request_counts, "ConcurrentAudioFirst", "later ")


class BrowserWidgetConcurrentAudioPlay(BrowserWidgetConcurrentAudioTestCase):
    """Two widgets playing audio; the first plays new audio with play() after the second interrupted it."""

    def run(self):
        recording_file, request_counts = self.record_pages("ConcurrentAudioFirstPlay")
        self.assert_started_playing(request_counts, "ConcurrentAudioFirstPlay", "later ")
        self.assert_first_beeps_after_second_beeps(recording_file)


class BrowserWidgetConcurrentAudioSamePage(BrowserWidgetTestCase):
    """Two videos playing audio in one widget; the first continues after the second played for 5 seconds."""

    def run(self):
        self.skip_if_missing_capability(Capability.SAME_PAGE_CONCURRENT_AUDIO)
        manual_volume_requirement(LOGGER)
        create_media()
        with HttpServer(WEB_SERVER_PORT, WEBSITES_DIR, self.moblin.config.tester_ip_address()) as server:
            self.moblin.import_settings(
                overrides={
                    "streams": [RECORD_STREAM_SETTINGS],
                    "scenes": [
                        {
                            "cameraPosition": CameraPosition.NONE,
                            "widgets": [scene_widget_settings(SAME_PAGE_WIDGET_ID, 0, 0, 50)],
                            "enabled": True,
                        }
                    ],
                    "widgets": [
                        browser_widget_settings(
                            "Browser",
                            SAME_PAGE_WIDGET_ID,
                            page_url(server, "ConcurrentAudioSamePage"),
                        )
                    ],
                }
            )
            recording_file = self.moblin.record(18, "BrowserWidgetConcurrentAudioSamePage.mp4")
            request_counts = server.request_counts()
        log_reports(request_counts)
        self.assert_started_playing(request_counts, "ConcurrentAudioSamePage", "first ")
        self.assert_started_playing(request_counts, "ConcurrentAudioSamePage", "second ")
        self.assert_first_beeps_after_second_beeps(recording_file)


def tests(moblin: Moblin):
    return [
        BrowserWidgetModes(moblin),
        BrowserWidgetStatic(moblin),
        BrowserWidgetScriptTiming(moblin),
        BrowserWidgetGlobalNames(moblin),
        BrowserWidgetFlexLayout(moblin),
        BrowserWidgetVideoAlert(moblin),
        BrowserWidgetBodyReplace(moblin),
        BrowserWidgetHiddenVideo(moblin),
        BrowserWidgetIframe(moblin),
        BrowserWidgetLog(moblin),
        BrowserWidgetReloadAfterFailedLoad(moblin),
        BrowserWidgetReloadAfterFailedLoadHttpProxy(moblin),
        BrowserWidgetAudioElement(moblin),
        BrowserWidgetAudioLate(moblin),
        BrowserWidgetVideoSound(moblin),
        BrowserWidgetWebAudio(moblin),
        BrowserWidgetConcurrentAudio(moblin),
        BrowserWidgetConcurrentAudioPlay(moblin),
        BrowserWidgetConcurrentAudioSamePage(moblin),
    ]
