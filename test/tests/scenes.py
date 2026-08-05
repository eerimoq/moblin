import logging
import time
from pathlib import Path

from utils.ffmpeg import FfmpegServer
from utils.ffmpeg import ffprobe_video
from utils.ffmpeg import read_video_frame
from utils.ffmpeg import remove_duplicated_frames
from utils.moblin import Moblin
from utils.test_case import TestCase
from utils.utils import Crop
from utils.utils import Image
from utils.utils import Pixel
from utils.utils import manual_confirmation

LOGGER = logging.getLogger(__name__)
STREAM = "Record H.265 1920x1080@30"
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


def _is_map_dot(pixel: Pixel) -> bool:
    """The map dot is much bluer than water, roads and other blueish map features."""

    return (
        pixel.blue > 180
        and pixel.blue - pixel.red > 80
        and pixel.blue - pixel.green > 60
    )


def _measure_map_dot(image: Image, x_step: int, y_step: int) -> int:
    """Number of map dot pixels in a line through the middle of the map."""

    length = 1
    for direction in [1, -1]:
        x = image.width // 2 + direction * x_step
        y = image.height // 2 + direction * y_step
        while image.contains(x, y) and _is_map_dot(image.pixel(x, y)):
            length += 1
            x += direction * x_step
            y += direction * y_step
    return length


class SceneSwitchMultipleTimes(TestCase):
    """Switch between two scenes a few times."""

    def run(self):
        for _ in range(10):
            self.moblin.set_scene("Screen")
            self.moblin.set_scene("Front")


class ScenePiPBackFront(TestCase):
    """A picture in picture scene with full screen back camera and small front camera in
    bottom right. Record for a few seconds and validate the recording.

    NOTE: Static scenes will make this test fail!

    """

    def __init__(self, moblin: Moblin, fps: int):
        super().__init__(moblin, f"ScenePiPBackFront{fps}Fps")
        self._fps = fps

    def setup(self):
        self.skip_if_missing_capability("pip")
        self.skip_if_no_moving_picture()
        self.moving_picture_on()

    def run(self):
        self.moblin.set_stream(f"SRT 5Mbps 1080@{self._fps}")
        self.moblin.set_scene("PiP")
        time.sleep(2)
        self.moblin.start_recording()
        time.sleep(10)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(
            f"ScenePiPBackFront{self._fps}.mp4"
        )
        self.assert_recording(
            recording_file,
            has_qr_codes=False,
            duplicated_frames_crops=[
                # Top left
                Crop(x=0, y=0, width=800, height=500),
                # Bottom right
                Crop(x=1120, y=580, width=800, height=500),
            ],
            fps=self._fps,
        )


class SceneWidgetsInBackground(TestCase):
    """Stream in background mode with various widgets showing."""

    def setup(self):
        self.skip_if_missing_capability("background-streaming")

    def run(self):
        filename = Path("files/ScenewidgetsInBackground.ts")
        self.moblin.set_scene("Background streaming")
        with FfmpegServer(url="srt://0.0.0.0:8890?mode=listener", filename=filename):
            self.moblin.set_stream("Background streaming")
            self.moblin.go_live()
            manual_confirmation("Put the app in background.")
            LOGGER.info("Streaming in background for 10 more seconds")
            time.sleep(10)
            self.moblin.end()
            manual_confirmation("Put the app in foreground.")
        crop = Crop(x=0, y=0, width=400, height=100)
        filtered_video = ffprobe_video(remove_duplicated_frames(filename, crop))
        for frame in filtered_video.frames:
            print(frame.pts)
        self.assert_presentation_time_stamps(
            filename, 1, [frame.pts for frame in filtered_video.frames[-8:]], 0.25
        )


class WidgetTestCase(TestCase):
    def record(self, scene: str, filename: str) -> Path:
        self.moblin.set_stream(STREAM)
        self.moblin.set_scene(scene)
        time.sleep(WARM_UP_TIME)
        self.moblin.start_recording()
        time.sleep(RECORDING_TIME)
        self.moblin.stop_recording()
        recording_file = self.moblin.download_and_delete_latest_recording(filename)
        self.assert_video_size(recording_file, WIDTH, HEIGHT)
        return recording_file

    def assert_widget_rendered(self, recording_file: Path, crop: Crop):
        self.assert_not_all_black(
            read_video_frame(recording_file, FRAME_TIMESTAMP, crop)
        )

    def assert_black_background(self, recording_file: Path):
        self.assert_all_black(
            read_video_frame(recording_file, FRAME_TIMESTAMP, BACKGROUND_CROP)
        )


class SceneMapWidget(WidgetTestCase):
    """One small and one large map widget on top of a scene without video source.
    Validate that both maps are rendered and that their blue dots are equally big.

    """

    def run(self):
        recording_file = self.record("Map", "MapWidget.mp4")
        self.assert_map(recording_file, "small", SMALL_MAP_CROP)
        self.assert_map(recording_file, "large", LARGE_MAP_CROP)
        self.assert_black_background(recording_file)

    def assert_map(self, recording_file: Path, name: str, crop: Crop):
        image = read_video_frame(recording_file, FRAME_TIMESTAMP, crop)
        self.assert_not_all_black(image)
        self.assert_true(
            _is_map_dot(image.pixel(image.width // 2, image.height // 2)),
            f"No blue dot in the middle of the {name} map",
        )
        width = _measure_map_dot(image, x_step=1, y_step=0)
        height = _measure_map_dot(image, x_step=0, y_step=1)
        LOGGER.info("The %s map's blue dot is %dx%d pixels", name, width, height)
        self.assert_in(width, ACCEPTED_MAP_DOT_SIDES, f"The {name} map's dot width")
        self.assert_in(height, ACCEPTED_MAP_DOT_SIDES, f"The {name} map's dot height")


class ScenePngTuberWidget(WidgetTestCase):
    """A PNGTuber widget on top of a scene without video source. Validate that the model
    is rendered.

    """

    def run(self):
        recording_file = self.record("PNGTuber", "PngTuberWidget.mp4")
        self.assert_widget_rendered(recording_file, TUBER_CROP)
        self.assert_black_background(recording_file)


class SceneVTuberWidget(WidgetTestCase):
    """A VTuber widget on top of a scene without video source. Validate that the model is
    rendered.

    """

    def run(self):
        recording_file = self.record("VTuber", "VTuberWidget.mp4")
        self.assert_widget_rendered(recording_file, TUBER_CROP)
        self.assert_black_background(recording_file)


def tests(moblin: Moblin):
    return [
        SceneSwitchMultipleTimes(moblin),
        ScenePiPBackFront(moblin, fps=30),
        ScenePiPBackFront(moblin, fps=60),
        SceneWidgetsInBackground(moblin),
        SceneMapWidget(moblin),
        ScenePngTuberWidget(moblin),
        SceneVTuberWidget(moblin),
    ]
