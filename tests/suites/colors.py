import time
from dataclasses import dataclass
from pathlib import Path

from systest import wait_until
from systest_moblin.ffmpeg import FfmpegCommand
from systest_moblin.ffmpeg import FfmpegServer
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import ffprobe_format
from systest_moblin.ffmpeg import ffprobe_run

from ..utils.color_chart import DEFAULT_COLOR_TAGS
from ..utils.color_chart import LIMITED_COLOR_TAGS
from ..utils.color_chart import display_p3_to_srgb
from ..utils.color_chart import gray_ramp
from ..utils.color_chart import hlg_to_srgb
from ..utils.color_chart import measure_chart_errors
from ..utils.color_chart import read_color_tags
from ..utils.color_chart import read_frames_color_tags
from ..utils.color_chart import read_patch_colors
from ..utils.color_chart import write_color_chart
from ..utils.config import SRT_SERVER_PORT
from ..utils.config import Capability
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import ColorRange
from ..utils.generate_device_settings import ColorSpace
from ..utils.generate_device_settings import GraphicsImplementation
from ..utils.generate_device_settings import Resolution
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import VideoCodec
from ..utils.generate_device_settings import WidgetType
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import Range

CHART_WIDGET_ID = uuid()
APPLE_LOG_LUT_ID = uuid()
CHART_FILE = FILES_DIR / "color-chart.png"
INGEST_ID = uuid()
RECORDING_TIME = 5
MAXIMUM_MEAN_ERROR = 2.0
MAXIMUM_ERROR = 6.0
HDR_VIDEO_FORMAT = ("hevc", "Main 10", "yuv420p10le")
GRAPHICS_IMPLEMENTATION_NAMES = {
    GraphicsImplementation.CORE_IMAGE: "CoreImage",
    GraphicsImplementation.METAL_PETAL: "MetalPetal",
}
CAMERA_NAMES = {
    CameraPosition.NONE: "NoCamera",
    CameraPosition.FRONT: "FrontCamera",
}


@dataclass
class ColorSpaceCase:
    name: str
    color_space: ColorSpace
    lut_enabled: bool
    capability: Capability
    color_tags: tuple[str | None, str | None, str | None] | None
    hdr: bool = False


COLOR_SPACE_CASES = [
    ColorSpaceCase(
        "P3", ColorSpace.P3_D65, False, Capability.P3_COLOR_SPACE, ("smpte432", "bt709", "smpte170m")
    ),
    ColorSpaceCase(
        "Hlg",
        ColorSpace.HLG_BT2020,
        False,
        Capability.HLG_COLOR_SPACE,
        ("bt2020", "arib-std-b67", "bt2020nc"),
        hdr=True,
    ),
    ColorSpaceCase(
        "AppleLog",
        ColorSpace.APPLE_LOG,
        False,
        Capability.APPLE_LOG_COLOR_SPACE,
        ("bt2020", None, "bt2020nc"),
    ),
    ColorSpaceCase("AppleLogLut", ColorSpace.APPLE_LOG, True, Capability.APPLE_LOG_COLOR_SPACE, None),
]


class FfmpegColorChartStream(FfmpegCommand):
    def __init__(self, url: str, chart_file: Path) -> None:
        super().__init__()
        self._url = url
        self._chart_file = chart_file

    def args(self) -> list[str]:
        return [
            "-re",
            "-loop",
            "1",
            "-framerate",
            "30",
            "-i",
            str(self._chart_file),
            "-re",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=1000:sample_rate=48000",
            "-vf",
            "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
            "-colorspace",
            "bt709",
            "-color_primaries",
            "bt709",
            "-color_trc",
            "bt709",
            "-color_range",
            "tv",
            "-c:v",
            "libx264",
            "-b:v",
            "8M",
            "-g",
            "30",
            "-c:a",
            "aac",
            "-f",
            TransportFormat.MPEGTS,
            self._url,
        ]


def ingest_scene(name: SceneName) -> dict:
    return {
        "name": name,
        "cameraPosition": CameraPosition.SRTLA,
        "srtlaCameraId": INGEST_ID,
        "micId": mic_id(INGEST_ID),
        "overrideMic": True,
        "enabled": True,
    }


def chart_scene(name: SceneName, camera_position: CameraPosition) -> dict:
    return {
        "name": name,
        "cameraPosition": camera_position,
        "widgets": [scene_widget_settings(CHART_WIDGET_ID, x=0, y=0, size=100)],
        "enabled": True,
    }


class ColorsTestCase(TestCase):
    def __init__(self, moblin: Moblin, name: str | None = None, color_range: ColorRange = ColorRange.FULL):
        name = name or type(self).__name__
        if color_range == ColorRange.LIMITED:
            name += "Limited"
        super().__init__(moblin, name)
        self.color_range = color_range
        self.color_tags = LIMITED_COLOR_TAGS if color_range == ColorRange.LIMITED else DEFAULT_COLOR_TAGS

    def import_settings(
        self,
        scenes: list[dict],
        graphics_implementation: GraphicsImplementation = GraphicsImplementation.CORE_IMAGE,
        video_codec: VideoCodec = VideoCodec.H265,
        color: dict | None = None,
        clean_recordings: bool = False,
        **overrides,
    ):
        write_color_chart(CHART_FILE)
        self.moblin.import_settings(
            overrides={
                "color": color or {"space": ColorSpace.SRGB},
                "graphicsImplementation": graphics_implementation,
                "streams": [
                    {
                        "enabled": True,
                        "fps": 30,
                        "resolution": Resolution.FULL_HD,
                        "codec": video_codec,
                        "colorRange": self.color_range,
                        "bitrate": 5_000_000,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "recording": {"videoCodec": video_codec, "cleanRecordings": clean_recordings},
                    }
                ],
                "scenes": scenes,
                "widgets": [{"id": CHART_WIDGET_ID, "name": "Chart", "type": WidgetType.IMAGE}],
                **overrides,
            },
            files={f"Images/{CHART_WIDGET_ID}": CHART_FILE},
        )

    def stream(self) -> Path:
        filename = FILES_DIR / f"{self.name}.ts"
        with FfmpegServer(url=srt_listener_url(), filename=filename):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        return filename

    def assert_color_tags(self, path: Path):
        self.assert_equal(read_color_tags(path), self.color_tags)

    def assert_frames_color_tags(self, path: Path):
        self.assert_equal(read_frames_color_tags(path), [self.color_tags])

    def read_chart(
        self, path: Path, scale: float = 1.0, timestamp: float | None = None
    ) -> list[tuple[float, float, float]]:
        if timestamp is None:
            timestamp = ffprobe_format(path).duration / 2
        return read_patch_colors(path, timestamp, scale)

    def assert_chart(self, path: Path, timestamp: float | None = None):
        errors = measure_chart_errors(self.read_chart(path, timestamp=timestamp))
        self.assert_less(errors.mean, MAXIMUM_MEAN_ERROR, f"Chart error {errors}")
        self.assert_less(errors.maximum, MAXIMUM_ERROR, f"Chart error {errors}")


class ColorsChartRecording(ColorsTestCase):
    """Record a full frame color chart image widget and validate color metadata and colors."""

    def __init__(
        self,
        moblin: Moblin,
        camera_position: CameraPosition,
        graphics_implementation: GraphicsImplementation,
        video_codec: VideoCodec,
        color_range: ColorRange = ColorRange.FULL,
    ):
        super().__init__(
            moblin,
            f"ColorsChartRecording{CAMERA_NAMES[camera_position]}"
            f"{GRAPHICS_IMPLEMENTATION_NAMES[graphics_implementation]}{video_codec.name}",
            color_range,
        )
        self._camera_position = camera_position
        self._graphics_implementation = graphics_implementation
        self._video_codec = video_codec

    def setup(self):
        self.import_settings(
            [chart_scene(SceneName.FRONT, self._camera_position)],
            self._graphics_implementation,
            self._video_codec,
        )

    def run(self):
        recording_file = self.moblin.record(RECORDING_TIME, f"{self.name}.mp4")
        self.assert_color_tags(recording_file)
        self.assert_chart(recording_file)


class ColorsChartStream(ColorsTestCase):
    """Stream a full frame color chart image widget over SRT and validate color metadata and colors."""

    def __init__(
        self,
        moblin: Moblin,
        camera_position: CameraPosition,
        video_codec: VideoCodec,
        color_range: ColorRange = ColorRange.FULL,
    ):
        super().__init__(
            moblin,
            f"ColorsChartStream{CAMERA_NAMES[camera_position]}{video_codec.name}",
            color_range,
        )
        self._camera_position = camera_position
        self._video_codec = video_codec

    def setup(self):
        self.import_settings(
            [chart_scene(SceneName.FRONT, self._camera_position)],
            video_codec=self._video_codec,
        )

    def run(self):
        stream_file = self.stream()
        self.assert_color_tags(stream_file)
        self.assert_chart(stream_file)


class ColorsCameraPassThrough(ColorsTestCase):
    """Record and stream a camera without widgets and validate that both carry its color metadata."""

    def __init__(
        self, moblin: Moblin, builtin_delay: float | None = None, color_range: ColorRange = ColorRange.FULL
    ):
        name = "ColorsCameraPassThrough"
        if builtin_delay is not None:
            name += f"BuiltinDelay{round(builtin_delay * 1000)}ms"
        super().__init__(moblin, name, color_range)
        self._builtin_delay = builtin_delay

    def setup(self):
        overrides: dict = {}
        if self._builtin_delay is not None:
            overrides["debug"] = {"logLevel": "Debug", "builtinAudioAndVideoDelay": self._builtin_delay}
        self.import_settings(
            [{"name": SceneName.FRONT, "cameraPosition": CameraPosition.FRONT, "enabled": True}],
            **overrides,
        )

    def run(self):
        recording_file = self.moblin.record(RECORDING_TIME, f"{self.name}.mp4")
        stream_file = self.stream()
        self.assert_color_tags(recording_file)
        self.assert_color_tags(stream_file)


class ColorsCleanRecording(ColorsTestCase):
    """Record a camera under a color chart widget as a clean recording and validate its camera color metadata."""

    def setup(self):
        self.import_settings([chart_scene(SceneName.FRONT, CameraPosition.FRONT)], clean_recordings=True)

    def run(self):
        recording_file = self.moblin.record(RECORDING_TIME, f"{self.name}.mp4")
        stream_file = self.stream()
        self.assert_color_tags(recording_file)
        errors = measure_chart_errors(self.read_chart(recording_file))
        self.assert_greater(errors.mean, MAXIMUM_MEAN_ERROR, f"Chart in clean recording {errors}")
        self.assert_color_tags(stream_file)
        self.assert_chart(stream_file)


class ColorsSceneSwitch(ColorsTestCase):
    """Switch between camera and color chart scenes while recording and streaming, and validate frame metadata."""

    def setup(self):
        self.import_settings(
            [
                {"name": SceneName.FRONT, "cameraPosition": CameraPosition.FRONT, "enabled": True},
                chart_scene(SceneName.EMPTY, CameraPosition.NONE),
            ]
        )

    def run(self):
        filename = FILES_DIR / f"{self.name}.ts"
        with (
            FfmpegServer(url=srt_listener_url(), filename=filename),
            Recorder(self.moblin, f"{self.name}.mp4") as recorder,
        ):
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 2_000_000)
            for scene in [SceneName.EMPTY, SceneName.FRONT, SceneName.EMPTY, SceneName.FRONT]:
                self.moblin.set_scene(scene)
                time.sleep(1)
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        for path in [filename, recorder.recording]:
            self.assert_frames_color_tags(path)


def read_colorimetry(path: Path) -> tuple[str | None, str | None, str | None]:
    tags = read_color_tags(path)
    return (tags["color_primaries"], tags["color_transfer"], tags["color_space"])


class ColorsColorSpace(ColorsTestCase):
    """Record and stream the back camera in a color space and validate color metadata and chart colors."""

    def __init__(
        self,
        moblin: Moblin,
        case: ColorSpaceCase,
        widget: bool,
        camera_position: CameraPosition = CameraPosition.BACK,
        graphics_implementation: GraphicsImplementation = GraphicsImplementation.CORE_IMAGE,
        color_range: ColorRange = ColorRange.FULL,
    ):
        name = f"ColorsColorSpace{case.name}{'Chart' if widget else 'Camera'}"
        if camera_position == CameraPosition.NONE:
            name += "NoCamera"
        if graphics_implementation != GraphicsImplementation.CORE_IMAGE:
            name += GRAPHICS_IMPLEMENTATION_NAMES[graphics_implementation]
        super().__init__(moblin, name, color_range)
        self._case = case
        self._widget = widget
        self._camera_position = camera_position
        self._graphics_implementation = graphics_implementation

    def setup(self):
        self.skip_if_missing_capability(self._case.capability)
        widgets = [scene_widget_settings(CHART_WIDGET_ID, x=0, y=0, size=50)] if self._widget else []
        self.import_settings(
            [
                {
                    "name": SceneName.BACK,
                    "cameraPosition": self._camera_position,
                    "widgets": widgets,
                    "enabled": True,
                }
            ],
            self._graphics_implementation,
            color={
                "space": self._case.color_space,
                "lutEnabled": self._case.lut_enabled,
                "lut": APPLE_LOG_LUT_ID,
                "bundledLuts": [{"id": APPLE_LOG_LUT_ID, "type": "bundled", "name": "Apple Log To Rec 709"}],
            },
        )

    def run(self):
        recording_file = self.moblin.record(RECORDING_TIME, f"{self.name}.mp4")
        stream_file = self.stream()
        recording_tags = read_colorimetry(recording_file)
        if self._case.color_tags is not None:
            self.assert_equal(recording_tags, self._case.color_tags)
        self.assert_equal(read_colorimetry(stream_file), recording_tags)
        if self._case.hdr:
            for path in [recording_file, stream_file]:
                self.assert_hdr(path)
        if self._widget:
            for path in [recording_file, stream_file]:
                self.assert_chart_in_color_space(path)

    def assert_hdr(self, path: Path):
        stream = ffprobe_run(path, "-select_streams", "v:0", "-show_streams")["streams"][0]
        self.assert_equal((stream["codec_name"], stream["profile"], stream["pix_fmt"]), HDR_VIDEO_FORMAT)

    def assert_chart_in_color_space(self, path: Path):
        colors = self.read_chart(path, 0.5)
        if self._case.color_space == ColorSpace.P3_D65:
            errors = measure_chart_errors([display_p3_to_srgb(color) for color in colors])
            self.assert_less(errors.mean, 2, f"Chart error {errors}")
            self.assert_less(errors.maximum, 10, f"Chart error {errors}")
        elif self._case.color_space == ColorSpace.HLG_BT2020:
            errors = measure_chart_errors([hlg_to_srgb(color) for color in colors])
            self.assert_less(errors.mean, 1.5, f"Chart error {errors}")
            self.assert_less(errors.maximum, 10, f"Chart error {errors}")
        grays = gray_ramp(colors)
        for gray in grays:
            self.assert_less(max(gray) - min(gray), 3, f"Gray tint in {gray}")
        levels = [sum(gray) / 3 for gray in grays]
        self.assert_true(all(a < b for a, b in zip(levels, levels[1:])), f"Gray ramp {levels}")
        if self._case.color_space == ColorSpace.HLG_BT2020:
            self.assert_in(round(levels[-1]), range(180, 201), f"HLG reference white {levels[-1]}")


class ColorsIngestTestCase(ColorsTestCase):
    def import_ingest_settings(self, scenes: list[dict], color: dict | None = None):
        self.import_settings(
            scenes,
            color=color,
            srtlaServer={
                "enabled": True,
                "srtPort": SRT_SERVER_PORT,
                "streams": [{"id": INGEST_ID, "name": "Chart", "streamId": "1"}],
            },
        )

    def wait_for_ingest(self):
        self.moblin.wait_for_ingests(bitrate=Range(0, 100_000_000), total_bytes=300_000, number_of_ingests=1)

    def ingest_stream(self) -> FfmpegColorChartStream:
        return FfmpegColorChartStream(self.moblin.ingest_srt_url(), CHART_FILE)


class ColorsIngestPassThrough(ColorsIngestTestCase):
    """Record and stream a BT.709 color chart SRT ingest without widgets and validate its colors."""

    def setup(self):
        self.import_ingest_settings([ingest_scene(SceneName.FRONT)])

    def run(self):
        with self.ingest_stream():
            self.wait_for_ingest()
            recording_file = self.moblin.record(RECORDING_TIME, f"{self.name}.mp4")
            stream_file = self.stream()
        for path in [recording_file, stream_file]:
            self.assert_frames_color_tags(path)
            self.assert_chart(path)


class ColorsIngestSceneSwitch(ColorsIngestTestCase):
    """Switch from a camera scene to a BT.709 color chart ingest scene and validate the ingest colors."""

    def setup(self):
        self.import_ingest_settings(
            [
                {"name": SceneName.FRONT, "cameraPosition": CameraPosition.FRONT, "enabled": True},
                ingest_scene(SceneName.EMPTY),
            ]
        )

    def run(self):
        stream_file = FILES_DIR / f"{self.name}.ts"
        with (
            self.ingest_stream(),
            FfmpegServer(url=srt_listener_url(), filename=stream_file),
            Recorder(self.moblin, f"{self.name}.mp4") as recorder,
        ):
            self.wait_for_ingest()
            self.moblin.go_live()
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 2_000_000)
            self.moblin.set_scene(SceneName.EMPTY)
            wait_until(lambda: "Chart" in self.moblin.get_camera_status(), "ingest scene to be selected")
            self.moblin.wait_for_bitrate(4_000_000, 6_000_000, None, 10_000_000)
            self.moblin.end()
        for path in [recorder.recording, stream_file]:
            self.assert_frames_color_tags(path)
            self.assert_chart(path, ffprobe_format(path).duration - 3)


def tests(moblin: Moblin):
    test_cases: list[TestCase] = []
    for camera_position in CAMERA_NAMES:
        for graphics_implementation in GraphicsImplementation:
            test_cases.append(
                ColorsChartRecording(moblin, camera_position, graphics_implementation, VideoCodec.H265)
            )
        test_cases.append(
            ColorsChartRecording(moblin, camera_position, GraphicsImplementation.CORE_IMAGE, VideoCodec.H264)
        )
        for video_codec in VideoCodec:
            test_cases.append(ColorsChartStream(moblin, camera_position, video_codec))
    test_cases += [
        ColorsCameraPassThrough(moblin),
        ColorsCameraPassThrough(moblin, 0.5),
        ColorsCleanRecording(moblin),
        ColorsSceneSwitch(moblin),
        ColorsIngestPassThrough(moblin),
        ColorsIngestSceneSwitch(moblin),
    ]
    for camera_position in CAMERA_NAMES:
        test_cases += [
            ColorsChartRecording(
                moblin,
                camera_position,
                GraphicsImplementation.CORE_IMAGE,
                VideoCodec.H265,
                ColorRange.LIMITED,
            ),
            ColorsChartStream(moblin, camera_position, VideoCodec.H264, ColorRange.LIMITED),
        ]
    test_cases += [
        ColorsCameraPassThrough(moblin, color_range=ColorRange.LIMITED),
        ColorsCleanRecording(moblin, color_range=ColorRange.LIMITED),
        ColorsSceneSwitch(moblin, color_range=ColorRange.LIMITED),
        ColorsIngestPassThrough(moblin, color_range=ColorRange.LIMITED),
        ColorsIngestSceneSwitch(moblin, color_range=ColorRange.LIMITED),
    ]
    for case in COLOR_SPACE_CASES:
        for widget in [False, True]:
            test_cases.append(ColorsColorSpace(moblin, case, widget))
        if case.hdr:
            test_cases += [
                ColorsColorSpace(moblin, case, widget=True, color_range=ColorRange.LIMITED),
                ColorsColorSpace(moblin, case, widget=True, camera_position=CameraPosition.NONE),
                ColorsColorSpace(
                    moblin, case, widget=True, graphics_implementation=GraphicsImplementation.METAL_PETAL
                ),
            ]
    return test_cases
