import logging
import time
from pathlib import Path

from ..utils.common.ffmpeg import Crop
from ..utils.common.ffmpeg import FfmpegNoiseStream
from ..utils.common.ffmpeg import FfmpegServer
from ..utils.common.ffmpeg import Image
from ..utils.common.ffmpeg import Pixel
from ..utils.common.ffmpeg import ffprobe_format
from ..utils.common.ffmpeg import read_unique_frame_presentation_time_stamps
from ..utils.common.ffmpeg import read_video_frame
from ..utils.config import RTMP_SERVER_PORT
from ..utils.config import Capability
from ..utils.config import srt_listener_url
from ..utils.generate_device_settings import BACK_SCENE_SETTINGS
from ..utils.generate_device_settings import FRONT_SCENE_SETTINGS
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import SCREEN_SCENE_SETTINGS
from ..utils.generate_device_settings import Alignment
from ..utils.generate_device_settings import BitrateRateControl
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import GraphicsImplementation
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import VideoStabilizationMode
from ..utils.generate_device_settings import WidgetType
from ..utils.generate_device_settings import download_model
from ..utils.generate_device_settings import mic_id
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import text_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.generate_device_settings import video_source_widget_settings
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import TestCase
from ..utils.utils import FILES_DIR
from ..utils.utils import manual_confirmation

LOGGER = logging.getLogger(__name__)
WIDTH = 1920
HEIGHT = 1080
WARM_UP_TIME = 5
RECORDING_TIME = 5
FRAME_TIMESTAMP = 2.5
SMALL_MAP_CROP = Crop(x=0, y=0, width=216, height=216)
LARGE_MAP_CROP = Crop(x=576, y=0, width=432, height=432)
TUBER_CROP = Crop(x=0, y=0, width=960, height=540)
BACKGROUND_CROP = Crop(x=0, y=600, width=WIDTH, height=480)
MAP_DOT_SIDE = 22
ACCEPTED_MAP_DOT_SIDES = range(MAP_DOT_SIDE - 3, MAP_DOT_SIDE + 4)
FRONT_VIDEO_SOURCE_WIDGET_ID = uuid()
TEXT_WIDGET_ID = "F4868489-D301-422D-A7DD-335572CA1312"
MAP_SMALL_WIDGET_ID = uuid()
MAP_LARGE_WIDGET_ID = uuid()
PNG_TUBER_WIDGET_ID = uuid()
V_TUBER_WIDGET_ID = uuid()
PNG_TUBER_MODEL_ID = uuid()
V_TUBER_MODEL_ID = uuid()
NOISE_TALKBACK_STREAM_ID = uuid()
V_TUBER_MODEL_NAME = "AliciaSolid.vrm"
PNG_TUBER_MODEL_NAME = "moblin.save"
GRAPHICS_IMPLEMENTATION_NAMES = {
    GraphicsImplementation.CORE_IMAGE: "CoreImage",
    GraphicsImplementation.METAL_PETAL: "MetalPetal",
}


def is_map_dot(pixel: Pixel) -> bool:
    return pixel.blue > 180 and pixel.blue - pixel.red > 80 and pixel.blue - pixel.green > 60


def measure_map_dot(image: Image, x_step: int, y_step: int) -> int:
    length = 1
    for direction in [1, -1]:
        x = image.width // 2 + direction * x_step
        y = image.height // 2 + direction * y_step
        while image.contains(x, y) and is_map_dot(image.pixel(x, y)):
            length += 1
            x += direction * x_step
            y += direction * y_step
    return length


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [FRONT_SCENE_SETTINGS, SCREEN_SCENE_SETTINGS],
            }
        )

    def run(self):
        for _ in range(10):
            self.moblin.set_scene(SceneName.SCREEN)
            self.moblin.set_scene(SceneName.FRONT)


class SceneSwitchBackAndFrontCameraAudio(TestCase):
    """Switch between a back camera scene and a front camera scene every two seconds
    while recording and streaming over SRT to the test runner computer with the default
    builtin microphone. White noise is played on the device's speaker over talkback for
    the microphone to pick up. Validate that the recorded and streamed audio has no
    glitches.

    """

    def __init__(self, moblin: Moblin, video_stabilization_mode: VideoStabilizationMode):
        super().__init__(moblin, f"{type(self).__name__}{video_stabilization_mode.name.title()}")
        self.video_stabilization_mode = video_stabilization_mode

    def setup(self):
        self.skip_if_missing_capability(Capability.PIP)
        self.moblin.import_settings(
            overrides={
                "streams": [
                    {
                        **RECORD_STREAM_SETTINGS,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                    }
                ],
                "scenes": [BACK_SCENE_SETTINGS, FRONT_SCENE_SETTINGS],
                "videoStabilizationMode": self.video_stabilization_mode,
                "rtmpServer": {
                    "enabled": True,
                    "port": RTMP_SERVER_PORT,
                    "streams": [
                        {
                            "id": NOISE_TALKBACK_STREAM_ID,
                            "name": "Noise",
                            "streamKey": "noise",
                        }
                    ],
                },
                "talkBack": {"enabled": True, "micId": mic_id(NOISE_TALKBACK_STREAM_ID)},
            }
        )
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        back_camera = self.select_scene(SceneName.BACK)
        front_camera = self.select_scene(SceneName.FRONT)
        self.assert_not_equal(back_camera, front_camera)
        recorder = Recorder(self.moblin, f"{self.name}.mp4")
        stream_file = FILES_DIR / f"{self.name}.ts"
        with FfmpegNoiseStream(self.moblin.ingest_rtmp_url("noise")):
            with FfmpegServer(url=srt_listener_url(), filename=stream_file):
                self.moblin.go_live()
                with recorder:
                    for _ in range(5):
                        self.assert_equal(self.select_scene(SceneName.BACK), back_camera)
                        time.sleep(2)
                        self.assert_equal(self.select_scene(SceneName.FRONT), front_camera)
                        time.sleep(2)
                self.moblin.end()
        self.assert_no_audio_glitches(recorder.recording)
        self.assert_no_audio_glitches(stream_file)

    def select_scene(self, name: SceneName) -> str:
        self.moblin.set_scene(name)
        return self.moblin.get_camera_status()


class GraphicsImplementationTestCase(TestCase):
    """Base class of test cases that are run once per graphics implementation."""

    def __init__(
        self,
        moblin: Moblin,
        graphics_implementation: GraphicsImplementation,
        name: str | None = None,
    ):
        self.graphics_implementation = graphics_implementation
        suffix = GRAPHICS_IMPLEMENTATION_NAMES[graphics_implementation]
        super().__init__(moblin, f"{name or type(self).__name__}{suffix}")


class ScenePiPBackFront(GraphicsImplementationTestCase):
    """A picture in picture scene with full screen back camera and small front camera in
    bottom right. Record for a few seconds and validate the recording.

    """

    def __init__(
        self,
        moblin: Moblin,
        fps: int,
        graphics_implementation: GraphicsImplementation,
    ):
        super().__init__(moblin, graphics_implementation, f"ScenePiPBackFront{fps}Fps")
        self._fps = fps

    def setup(self):
        self.skip_if_missing_capability(Capability.PIP)
        self.moving_picture_on()
        self.moblin.import_settings(
            overrides={
                "graphicsImplementation": self.graphics_implementation,
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                        "fps": self._fps,
                    }
                ],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.BACK,
                        "backCameraId": "com.apple.avfoundation.avcapturedevice.built-in_video:0",
                        "widgets": [
                            scene_widget_settings(
                                FRONT_VIDEO_SOURCE_WIDGET_ID,
                                x=0,
                                y=0,
                                size=50,
                                alignment=Alignment.BOTTOM_RIGHT,
                            )
                        ],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    video_source_widget_settings(
                        "Front",
                        FRONT_VIDEO_SOURCE_WIDGET_ID,
                        {
                            "cameraPosition": CameraPosition.FRONT,
                            "frontCameraId": "com.apple.avfoundation.avcapturedevice.built-in_video:1",
                        },
                    )
                ],
            }
        )

    def run(self):
        time.sleep(2)
        recording_file = self.moblin.record(10, f"{self.name}.mp4")
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            duplicated_frames_crops=(
                [
                    # Top left
                    Crop(x=0, y=0, width=800, height=500),
                    # Bottom right
                    Crop(x=1120, y=580, width=800, height=500),
                ]
                if self.moblin.has_moving_picture()
                else []
            ),
            fps=self._fps,
        )


class SceneWidgetsInBackground(GraphicsImplementationTestCase):
    """Stream in background mode with a clock widget showing. Validate that the widget
    is updated once per second with Core Image, and not updated at all with Metal Petal,
    which is not allowed to run in background.

    """

    def setup(self):
        self.skip_if_missing_capability(Capability.BACKGROUND_STREAMING)
        self.skip_if_not_interactive()
        self.moblin.import_settings(
            overrides={
                "graphicsImplementation": self.graphics_implementation,
                "streams": [
                    {
                        "enabled": True,
                        "bitrateRateControl": BitrateRateControl.CBR,
                        "url": self.moblin.tester_srt_publish_url("test"),
                        "srt": {"adaptiveBitrateEnabled": False},
                        "bitrate": 5_000_000,
                        "backgroundStreaming": True,
                        "backgroundStreamingPiP": False,
                    }
                ],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.SCREEN_CAPTURE,
                        "widgets": [scene_widget_settings(TEXT_WIDGET_ID, x=0, y=0, size=100)],
                        "enabled": True,
                    }
                ],
                "widgets": [
                    text_widget_settings(
                        "Time",
                        TEXT_WIDGET_ID,
                        {"formatString": "{time}", "fontSize": 80},
                    )
                ],
            }
        )

    def run(self):
        filename = FILES_DIR / f"{self.name}.ts"
        with FfmpegServer(url=srt_listener_url(), filename=filename):
            self.moblin.go_live()
            manual_confirmation("Put the app in background.")
            LOGGER.info("Streaming in background for 10 more seconds")
            time.sleep(10)
            self.moblin.end()
            manual_confirmation("Put the app in foreground.")
        self.assert_live_stream(filename, maximum_length=None)
        crop = Crop(x=0, y=0, width=400, height=100)
        presentation_time_stamps = read_unique_frame_presentation_time_stamps(filename, crop)
        if self.graphics_implementation == GraphicsImplementation.CORE_IMAGE:
            self.assert_presentation_time_stamps(
                filename, 1, presentation_time_stamps[-8:], "widget", delta_error=0.25
            )
        else:
            background_start = ffprobe_format(filename).duration - 8
            self.assert_equal(
                [pts for pts in presentation_time_stamps if pts > background_start],
                [],
                "Widgets updated in background",
            )


class WidgetTestCase(GraphicsImplementationTestCase):
    def import_settings(self, scene_widgets, widgets, files: dict[str, Path] | None = None):
        self.moblin.import_settings(
            overrides={
                "graphicsImplementation": self.graphics_implementation,
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "cameraPosition": CameraPosition.NONE,
                        "widgets": scene_widgets,
                        "enabled": True,
                    }
                ],
                "widgets": widgets,
            },
            files=files,
        )

    def record(self, filename: str) -> Path:
        time.sleep(WARM_UP_TIME)
        recording_file = self.moblin.record(RECORDING_TIME, filename)
        self.assert_video_size(recording_file, WIDTH, HEIGHT)
        return recording_file

    def assert_widget_rendered(self, recording_file: Path, crop: Crop):
        self.assert_not_all_black(read_video_frame(recording_file, FRAME_TIMESTAMP, crop))

    def assert_black_background(self, recording_file: Path):
        self.assert_all_black(read_video_frame(recording_file, FRAME_TIMESTAMP, BACKGROUND_CROP))


class SceneMapWidget(WidgetTestCase):
    """One small and one large map widget on top of a scene without video source.
    Validate that both maps are rendered and that their blue dots are equally big.

    """

    def setup(self):
        self.import_settings(
            scene_widgets=[
                scene_widget_settings(MAP_SMALL_WIDGET_ID, x=0, y=0, size=20),
                scene_widget_settings(MAP_LARGE_WIDGET_ID, x=30, y=0, size=40),
            ],
            widgets=[
                {
                    "id": MAP_SMALL_WIDGET_ID,
                    "name": "Map small",
                    "type": WidgetType.MAP,
                },
                {
                    "id": MAP_LARGE_WIDGET_ID,
                    "name": "Map large",
                    "type": WidgetType.MAP,
                },
            ],
        )

    def run(self):
        recording_file = self.record(f"{self.name}.mp4")
        self.assert_map(recording_file, "small", SMALL_MAP_CROP)
        self.assert_map(recording_file, "large", LARGE_MAP_CROP)
        self.assert_black_background(recording_file)

    def assert_map(self, recording_file: Path, name: str, crop: Crop):
        image = read_video_frame(recording_file, FRAME_TIMESTAMP, crop)
        self.assert_not_all_black(image)
        self.assert_true(
            is_map_dot(image.pixel(image.width // 2, image.height // 2)),
            f"No blue dot in the middle of the {name} map",
        )
        width = measure_map_dot(image, x_step=1, y_step=0)
        height = measure_map_dot(image, x_step=0, y_step=1)
        self.assert_in(width, ACCEPTED_MAP_DOT_SIDES, f"The {name} map's dot width")
        self.assert_in(height, ACCEPTED_MAP_DOT_SIDES, f"The {name} map's dot height")


class ScenePngTuberWidget(WidgetTestCase):
    """A PNGTuber widget on top of a scene without video source. Validate that the model
    is rendered.

    """

    def setup(self):
        self.import_settings(
            scene_widgets=[scene_widget_settings(PNG_TUBER_WIDGET_ID, x=0, y=0, size=50)],
            widgets=[
                {
                    "id": PNG_TUBER_WIDGET_ID,
                    "type": WidgetType.PNG_TUBER,
                    "pngTuber": {
                        "id": PNG_TUBER_MODEL_ID,
                        "cameraPosition": CameraPosition.FRONT,
                        "modelName": PNG_TUBER_MODEL_NAME,
                    },
                }
            ],
            files={f"PNGTuber/{PNG_TUBER_MODEL_ID}": download_model(PNG_TUBER_MODEL_NAME)},
        )

    def run(self):
        recording_file = self.record(f"{self.name}.mp4")
        self.assert_widget_rendered(recording_file, TUBER_CROP)
        self.assert_black_background(recording_file)


class SceneVTuberWidget(WidgetTestCase):
    """A VTuber widget on top of a scene without video source. Validate that the model is
    rendered.

    """

    def setup(self):
        self.import_settings(
            scene_widgets=[scene_widget_settings(V_TUBER_WIDGET_ID, x=0, y=0, size=50)],
            widgets=[
                {
                    "id": V_TUBER_WIDGET_ID,
                    "type": WidgetType.V_TUBER,
                    "vTuber": {
                        "id": V_TUBER_MODEL_ID,
                        "cameraPosition": CameraPosition.FRONT,
                        "modelName": V_TUBER_MODEL_NAME,
                    },
                }
            ],
            files={f"VTuber/{V_TUBER_MODEL_ID}": download_model(V_TUBER_MODEL_NAME)},
        )

    def run(self):
        recording_file = self.record(f"{self.name}.mp4")
        self.assert_widget_rendered(recording_file, TUBER_CROP)
        self.assert_black_background(recording_file)


def tests(moblin: Moblin):
    test_cases = [
        SceneSwitchMultipleTimes(moblin),
        SceneSwitchBackAndFrontCameraAudio(moblin, VideoStabilizationMode.OFF),
        SceneSwitchBackAndFrontCameraAudio(moblin, VideoStabilizationMode.CINEMATIC),
    ]
    for graphics_implementation in GraphicsImplementation:
        test_cases += [
            ScenePiPBackFront(moblin, 30, graphics_implementation),
            ScenePiPBackFront(moblin, 60, graphics_implementation),
            SceneWidgetsInBackground(moblin, graphics_implementation),
            SceneMapWidget(moblin, graphics_implementation),
            ScenePngTuberWidget(moblin, graphics_implementation),
            SceneVTuberWidget(moblin, graphics_implementation),
        ]
    return test_cases
