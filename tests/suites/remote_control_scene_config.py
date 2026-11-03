import logging
import re
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from systest_moblin.ffmpeg import Crop
from systest_moblin.ffmpeg import FfmpegCommand
from systest_moblin.ffmpeg import FfmpegVideoCodec
from systest_moblin.ffmpeg import TransportFormat
from systest_moblin.ffmpeg import VideoRegionColors
from systest_moblin.ffmpeg import ffprobe_format
from systest_moblin.ffmpeg import read_video_frame
from systest_moblin.ffmpeg import read_video_region_colors
from systest_moblin.ffmpeg import video_encoder_args
from systest_moblin.test_case import log_watch_video

from ..utils.config import RTMP_SERVER_PORT
from ..utils.generate_device_settings import RECORD_STREAM_SETTINGS
from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import WidgetType
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import text_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.generate_device_settings import video_source_widget_settings
from ..utils.moblin import Moblin
from ..utils.moblin import Recorder
from ..utils.test_case import TestCase
from ..utils.utils import read_qr_code_in_video_frame
from ..utils.utils import read_text_in_video_frame

LOGGER = logging.getLogger(__name__)
STREAM_1_ID = uuid()
STREAM_2_ID = uuid()
STREAM_3_ID = uuid()
STREAM_4_ID = uuid()
INGEST_SCENE_ID = uuid()
OTHER_SCENE_ID = uuid()
STATIC_WIDGET_ID = uuid()
EDITED_WIDGET_ID = uuid()
MOVER_WIDGET_ID = uuid()
UNUSED_WIDGET_ID = uuid()
CREATED_WIDGET_ID = uuid()
VIDEO_SOURCE_WIDGET_ID = uuid()
SCOREBOARD_WIDGET_ID = uuid()
SNAPSHOT_WIDGET_ID = uuid()
RENDER_SCENE_ID = uuid()
INNER_SCENE_ID = uuid()
OTHER_INNER_SCENE_ID = uuid()
RENDER_TEXT_WIDGET_ID = uuid()
INNER_TEXT_WIDGET_ID = uuid()
OTHER_INNER_TEXT_WIDGET_ID = uuid()
NESTED_SCENE_WIDGET_ID = uuid()
QR_CODE_WIDGET_ID = uuid()
TEXT_BOX_WIDTH = 235
TEXT_BOX_HEIGHT = 95
STEP_INTERVAL = 2
STEP_MARGIN = 0.25
FROZEN_FRAMES = 5
QR_CODE_CROP = Crop(x=150, y=0, width=400, height=400)
STATIC_WIDGET_CROP = Crop(x=0, y=540, width=80, height=80)
EDITED_WIDGET_CROP = Crop(x=0, y=810, width=80, height=80)
MOVER_WIDGET_CROP = Crop(x=960, y=540, width=80, height=80)
MOVED_MOVER_WIDGET_CROP = Crop(x=1152, y=756, width=80, height=80)
EDITED_TEXT_CROP = Crop(x=0, y=815, width=250, height=95)
VIDEO_SOURCE_WIDGET_CROP = Crop(x=1560, y=165, width=48, height=48)
SCOREBOARD_WIDGET_CROP = Crop(x=1480, y=480, width=24, height=24)
WHITE = {"red": 255, "green": 255, "blue": 255}
BLACK = {"red": 0, "green": 0, "blue": 0}


class FfmpegQrCodeStream(FfmpegCommand):
    def __init__(self, url: str) -> None:
        super().__init__()
        self._url = url

    def args(self) -> list[str]:
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            "color=c=black:size=1920x1080:rate=30",
            "-re",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=1000:sample_rate=48000",
            *video_encoder_args(8_000_000, FfmpegVideoCodec.H264, True),
            "-pix_fmt",
            "yuv420p",
            "-g",
            "60",
            "-keyint_min",
            "60",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-ar",
            "48000",
            "-ac",
            "1",
            "-vf",
            "qrencode=text=n %{frame_num} pts %{pts}:q=400:x=150",
            "-f",
            TransportFormat.FLV,
            self._url,
        ]


class FfmpegColorStream(FfmpegCommand):
    def __init__(self, url: str, color: str) -> None:
        super().__init__()
        self._url = url
        self._color = color

    def args(self) -> list[str]:
        return [
            "-re",
            "-f",
            "lavfi",
            "-i",
            f"color=c={self._color}:size=640x360:rate=30",
            "-re",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=1000:sample_rate=48000",
            *video_encoder_args(1_000_000, FfmpegVideoCodec.H264, True),
            "-pix_fmt",
            "yuv420p",
            "-g",
            "60",
            "-keyint_min",
            "60",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-ar",
            "48000",
            "-ac",
            "1",
            "-f",
            TransportFormat.FLV,
            self._url,
        ]


@dataclass
class ConfigurationStep:
    name: str
    apply: Callable[[], dict]
    may_flicker: bool
    may_reattach_camera: bool


def is_same_frame(first: VideoRegionColors, second: VideoRegionColors) -> bool:
    return all(
        abs(first_color.red - second_color.red) <= 8
        and abs(first_color.green - second_color.green) <= 8
        and abs(first_color.blue - second_color.blue) <= 8
        for first_color, second_color in zip(first.colors, second.colors)
    )


def find_frozen_periods(recording: Path, duration: float) -> list[tuple[float, float]]:
    frames = read_video_region_colors(recording, QR_CODE_CROP, 8, 8, 0, duration)
    periods = []
    start = 0
    for index in range(1, len(frames) + 1):
        if index < len(frames) and is_same_frame(frames[index - 1], frames[index]):
            continue
        if index - start >= FROZEN_FRAMES:
            periods.append((frames[start].pts, frames[index - 1].pts))
        start = index
    return periods


def find_black_frames(recording: Path, crop: Crop, duration: float) -> list[float]:
    frames = read_video_region_colors(recording, crop, 1, 1, 0, duration)
    return [frame.pts for frame in frames if frame.colors[0].is_black()]


def scenes_by_id(moblin: Moblin) -> dict[str, dict]:
    return {scene["id"].upper(): scene for scene in moblin.get_scenes()}


def widgets_by_id(moblin: Moblin) -> dict[str, dict]:
    return {widget["id"].upper(): widget for widget in moblin.get_widgets()}


def text_widget(name: str, widget_id: str, format_string: str) -> dict:
    return text_widget_settings(
        name,
        widget_id,
        {
            "formatString": format_string,
            "backgroundColor": WHITE,
            "foregroundColor": BLACK,
            "fontSize": 80,
        },
    )


class RemoteControlSceneConfig(TestCase):
    """Create, update and delete scenes and widgets, and read editor options and alerts media, over remote control."""

    def setup(self):
        self.moblin.import_settings(overrides={})

    def _front_scene_id(self) -> str:
        for scene in self.moblin.get_scenes():
            if scene["name"] == SceneName.FRONT:
                return scene["id"]
        raise Exception("Front scene not found")

    def run(self):
        self.video_sources()
        self.editor_options()
        self.scenes_and_widgets()
        self.scoreboard_widget()
        self.alert_media()

    def editor_options(self):
        options = self.moblin.get_editor_options()
        self.assert_true(options["canvasSize"]["width"] > 0 and options["canvasSize"]["height"] > 0)
        self.assert_true(len(options["fonts"]) > 0)
        for key in [
            "luts",
            "scoreboardPlayers",
            "webRemote",
            "workoutDevices",
            "streamDeckLayouts",
            "appleVoices",
        ]:
            self.assert_in(key, options)
        player_id = uuid()
        self.assert_in("ok", self.moblin.set_scoreboard_players([{"id": player_id, "name": "Remote player"}]))
        self.assert_equal(
            [player["id"].upper() for player in self.moblin.get_editor_options()["scoreboardPlayers"]],
            [player_id],
        )
        self.assert_in("error", self.moblin.set_scoreboard_players([{"id": player_id}, {"id": player_id}]))
        self.assert_in("ok", self.moblin.set_scoreboard_players([]))

    def video_sources(self):
        video_sources = self.moblin.get_video_sources()
        self.assert_in(CameraPosition.NONE, [video_source["position"] for video_source in video_sources])

    def scenes_and_widgets(self):
        widget_id = uuid()
        scene_id = uuid()
        widget = text_widget_settings("Remote text", widget_id, {"formatString": "{time}"})
        self.assert_in("ok", self.moblin.create_widget(widget))
        self.assert_in("error", self.moblin.create_widget(widget))
        scene = {
            "id": scene_id,
            "name": "Remote",
            "cameraPosition": CameraPosition.BACK,
            "enabled": True,
            "widgets": [scene_widget_settings(widget_id, x=10, y=10, size=50)],
        }
        self.assert_in("ok", self.moblin.create_scene(scene))
        self.assert_in("error", self.moblin.create_scene(scene))
        self.assert_equal(scenes_by_id(self.moblin)[scene_id]["name"], "Remote")
        self.assert_equal(scenes_by_id(self.moblin)[scene_id]["widgets"][0]["widgetId"].upper(), widget_id)
        self.assert_equal(widgets_by_id(self.moblin)[widget_id]["text"]["formatString"], "{time}")
        self.moblin.set_scene_id(scene_id)
        self.moblin.wait_for_scene(scene_id)
        self.assert_in("ok", self.moblin.update_scene({**scene, "name": "Renamed"}))
        self.assert_equal(scenes_by_id(self.moblin)[scene_id]["name"], "Renamed")
        self.assert_in("error", self.moblin.update_scene({**scene, "id": uuid()}))
        widget["text"] = {"formatString": "{date}"}
        self.assert_in("ok", self.moblin.update_widget(widget))
        self.assert_equal(widgets_by_id(self.moblin)[widget_id]["text"]["formatString"], "{date}")
        self.assert_in("error", self.moblin.update_widget({**widget, "id": uuid()}))
        self.assert_in("ok", self.moblin.delete_widget(widget_id))
        self.assert_not_in(widget_id, widgets_by_id(self.moblin))
        self.assert_equal(scenes_by_id(self.moblin)[scene_id]["widgets"], [])
        self.assert_in("error", self.moblin.delete_widget(widget_id))
        self.assert_in("ok", self.moblin.delete_scene(scene_id))
        self.assert_not_in(scene_id, scenes_by_id(self.moblin))
        self.assert_in("error", self.moblin.delete_scene(scene_id))
        self.moblin.wait_for_scene(self._front_scene_id())

    def scoreboard_widget(self):
        widget_id = uuid()
        widget: dict = {
            "id": widget_id,
            "name": "Remote scoreboard",
            "type": WidgetType.SCOREBOARD,
            "enabled": True,
            "scoreboard": {"padel": {"homePlayer1": uuid()}},
        }
        self.assert_in("ok", self.moblin.create_widget(widget))
        widget = widgets_by_id(self.moblin)[widget_id]
        self.assert_in("ok", self.moblin.update_widget(widget))
        self.assert_in("ok", self.moblin.delete_widget(widget_id))

    def alert_media(self):
        gallery = self.moblin.get_alerts_media_gallery()
        self.assert_true(len(gallery["bundledImages"]) > 0)
        self.assert_true(len(gallery["bundledSounds"]) > 0)


class RemoteControlSceneConfigWhileRecording(TestCase):
    """Configure scenes over remote control while recording and check flicker and reattaches match the UI."""

    def __init__(self, moblin: Moblin):
        super().__init__(moblin)
        self.scene: dict = {}
        self.widgets: dict[str, dict] = {}
        self.other_scene = {
            "id": OTHER_SCENE_ID,
            "name": "Other",
            "cameraPosition": CameraPosition.NONE,
            "enabled": True,
            "widgets": [],
        }

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "id": INGEST_SCENE_ID,
                        "name": "Ingest",
                        "cameraPosition": CameraPosition.RTMP,
                        "rtmpCameraId": STREAM_1_ID,
                        "enabled": True,
                        "widgets": [
                            scene_widget_settings(STATIC_WIDGET_ID, x=0, y=50, size=100),
                            scene_widget_settings(EDITED_WIDGET_ID, x=0, y=75, size=100),
                            scene_widget_settings(MOVER_WIDGET_ID, x=50, y=50, size=100),
                            scene_widget_settings(VIDEO_SOURCE_WIDGET_ID, x=70, y=5, size=25),
                            scene_widget_settings(SCOREBOARD_WIDGET_ID, x=70, y=40, size=18.52),
                            scene_widget_settings(SNAPSHOT_WIDGET_ID, x=0, y=0, size=40),
                        ],
                    }
                ],
                "widgets": [
                    text_widget("Static", STATIC_WIDGET_ID, "Static"),
                    text_widget("Edited", EDITED_WIDGET_ID, "AAAA"),
                    text_widget("Mover", MOVER_WIDGET_ID, "Mover"),
                    text_widget("Unused", UNUSED_WIDGET_ID, "Unused"),
                    video_source_widget_settings(
                        "Video source",
                        VIDEO_SOURCE_WIDGET_ID,
                        {"cameraPosition": CameraPosition.RTMP, "rtmpCameraId": STREAM_3_ID},
                    ),
                    {
                        "id": SCOREBOARD_WIDGET_ID,
                        "name": "Scoreboard",
                        "type": WidgetType.SCOREBOARD,
                        "enabled": True,
                        "scoreboard": {},
                    },
                    {
                        "id": SNAPSHOT_WIDGET_ID,
                        "name": "Snapshot",
                        "type": WidgetType.SNAPSHOT,
                        "enabled": True,
                        "snapshot": {"showtime": 5},
                    },
                ],
                "rtmpServer": {
                    "enabled": True,
                    "port": RTMP_SERVER_PORT,
                    "streams": [
                        {"id": STREAM_1_ID, "name": "1", "streamKey": "1"},
                        {"id": STREAM_2_ID, "name": "2", "streamKey": "2"},
                        {"id": STREAM_3_ID, "name": "3", "streamKey": "3"},
                        {"id": STREAM_4_ID, "name": "4", "streamKey": "4"},
                    ],
                },
                "sceneSwitchTransition": "Freeze",
                "forceSceneSwitchTransition": True,
            }
        )
        self.moblin.wait_for_tcp_ports(RTMP_SERVER_PORT)

    def run(self):
        with (
            FfmpegQrCodeStream(self.moblin.ingest_rtmp_url("1")),
            FfmpegQrCodeStream(self.moblin.ingest_rtmp_url("2")),
            FfmpegColorStream(self.moblin.ingest_rtmp_url("3"), "green"),
            FfmpegColorStream(self.moblin.ingest_rtmp_url("4"), "yellow"),
        ):
            self.wait_for_ingest_stream_started(number_of_ingests=4)
            self.scene = scenes_by_id(self.moblin)[INGEST_SCENE_ID]
            self.widgets = widgets_by_id(self.moblin)
            steps = self.configuration_steps()
            step_times = []
            with Recorder(self.moblin, f"{self.name}.mp4") as recorder:
                recording_start = time.monotonic()
                time.sleep(STEP_INTERVAL)
                for step in steps:
                    LOGGER.info("Configuration step: %s", step.name)
                    step_times.append(time.monotonic() - recording_start)
                    self.assert_in("ok", step.apply(), step.name)
                    time.sleep(STEP_INTERVAL)
        self.assert_configuration_steps(recorder.recording, steps, step_times)

    def configuration_steps(self) -> list[ConfigurationStep]:
        return [
            ConfigurationStep(
                "Disable widget", lambda: self.set_widget_enabled(MOVER_WIDGET_ID, False), False, False
            ),
            ConfigurationStep(
                "Enable widget", lambda: self.set_widget_enabled(MOVER_WIDGET_ID, True), False, False
            ),
            ConfigurationStep("Rename scene", lambda: self.update_scene(name="Renamed"), False, False),
            ConfigurationStep("Move widget", lambda: self.update_mover_layout(x=60, y=70), False, False),
            ConfigurationStep("Resize widget", lambda: self.update_mover_layout(size=50), False, False),
            ConfigurationStep(
                "Reorder widgets",
                lambda: self.update_scene(widgets=self.scene["widgets"][::-1]),
                False,
                False,
            ),
            ConfigurationStep("Remove widget from scene", self.remove_mover_from_scene, False, False),
            ConfigurationStep("Add widget to scene", self.add_mover_to_scene, False, False),
            ConfigurationStep(
                "Change scene button color",
                lambda: self.update_scene(backgroundColor={"red": 255, "green": 0, "blue": 0}),
                False,
                False,
            ),
            ConfigurationStep(
                "Toggle fill frame",
                lambda: self.update_scene(fillFrame=not self.scene["fillFrame"]),
                False,
                True,
            ),
            ConfigurationStep(
                "Set quick switch group", lambda: self.update_scene(quickSwitchGroup=1), True, True
            ),
            ConfigurationStep(
                "Change video source", lambda: self.update_scene(rtmpCameraId=STREAM_2_ID), False, True
            ),
            ConfigurationStep(
                "Change text", lambda: self.update_text(EDITED_WIDGET_ID, formatString="BBBB"), False, False
            ),
            ConfigurationStep(
                "Change text foreground color",
                lambda: self.update_text(
                    EDITED_WIDGET_ID, foregroundColor={"red": 0, "green": 0, "blue": 255}
                ),
                False,
                False,
            ),
            ConfigurationStep(
                "Change text background color",
                lambda: self.update_text(
                    EDITED_WIDGET_ID, backgroundColor={"red": 255, "green": 255, "blue": 0}
                ),
                False,
                False,
            ),
            ConfigurationStep(
                "Change text font size", lambda: self.update_text(EDITED_WIDGET_ID, fontSize=90), False, False
            ),
            ConfigurationStep(
                "Rename widget", lambda: self.rename_widget(EDITED_WIDGET_ID, "Renamed"), False, False
            ),
            ConfigurationStep(
                "Mirror video source widget",
                lambda: self.update_widget(VIDEO_SOURCE_WIDGET_ID, "videoSource", mirror=True),
                False,
                False,
            ),
            ConfigurationStep(
                "Rotate video source widget",
                lambda: self.update_widget(VIDEO_SOURCE_WIDGET_ID, "videoSource", rotation=180),
                False,
                False,
            ),
            ConfigurationStep(
                "Change video source widget camera",
                lambda: self.update_widget(VIDEO_SOURCE_WIDGET_ID, "videoSource", rtmpCameraId=STREAM_4_ID),
                False,
                True,
            ),
            ConfigurationStep(
                "Add video source widget effect",
                lambda: self.add_gray_scale_effect(VIDEO_SOURCE_WIDGET_ID),
                True,
                True,
            ),
            ConfigurationStep(
                "Change scoreboard title",
                lambda: self.update_scoreboard_generic(title="Final"),
                False,
                False,
            ),
            ConfigurationStep(
                "Change scoreboard color",
                lambda: self.update_widget(
                    SCOREBOARD_WIDGET_ID,
                    "scoreboard",
                    primaryBackgroundColor={"red": 255, "green": 0, "blue": 0},
                ),
                False,
                False,
            ),
            ConfigurationStep(
                "Change snapshot showtime",
                lambda: self.update_widget(SNAPSHOT_WIDGET_ID, "snapshot", showtime=10),
                False,
                False,
            ),
            ConfigurationStep(
                "Add snapshot effect",
                lambda: self.add_gray_scale_effect(SNAPSHOT_WIDGET_ID),
                True,
                True,
            ),
            ConfigurationStep(
                "Change text delay of unused widget",
                lambda: self.update_text(UNUSED_WIDGET_ID, delay=1),
                True,
                True,
            ),
            ConfigurationStep(
                "Create widget",
                lambda: self.moblin.create_widget(text_widget("Created", CREATED_WIDGET_ID, "Created")),
                True,
                False,
            ),
            ConfigurationStep(
                "Delete widget", lambda: self.moblin.delete_widget(CREATED_WIDGET_ID), True, True
            ),
            ConfigurationStep(
                "Create scene", lambda: self.moblin.create_scene(self.other_scene), False, False
            ),
            ConfigurationStep(
                "Rename other scene",
                lambda: self.moblin.update_scene({**self.other_scene, "name": "Renamed other"}),
                False,
                False,
            ),
            ConfigurationStep(
                "Delete other scene", lambda: self.moblin.delete_scene(OTHER_SCENE_ID), False, False
            ),
            ConfigurationStep(
                "Set scoreboard players",
                lambda: self.moblin.set_scoreboard_players([{"id": uuid(), "name": "Player"}]),
                False,
                False,
            ),
        ]

    def update_scene(self, **changes) -> dict:
        self.scene.update(changes)
        return self.moblin.update_scene(self.scene)

    def mover_scene_widget(self) -> dict:
        return next(
            scene_widget
            for scene_widget in self.scene["widgets"]
            if scene_widget["widgetId"].upper() == MOVER_WIDGET_ID
        )

    def update_mover_layout(self, **changes) -> dict:
        self.mover_scene_widget().update(changes)
        return self.moblin.update_scene(self.scene)

    def remove_mover_from_scene(self) -> dict:
        mover_scene_widget = self.mover_scene_widget()
        return self.update_scene(
            widgets=[
                scene_widget
                for scene_widget in self.scene["widgets"]
                if scene_widget is not mover_scene_widget
            ]
        )

    def add_mover_to_scene(self) -> dict:
        return self.update_scene(
            widgets=self.scene["widgets"] + [scene_widget_settings(MOVER_WIDGET_ID, x=60, y=70, size=50)]
        )

    def set_widget_enabled(self, widget_id: str, enabled: bool) -> dict:
        self.widgets[widget_id]["enabled"] = enabled
        return self.moblin.update_widget(self.widgets[widget_id])

    def rename_widget(self, widget_id: str, name: str) -> dict:
        self.widgets[widget_id]["name"] = name
        return self.moblin.update_widget(self.widgets[widget_id])

    def update_text(self, widget_id: str, **changes) -> dict:
        return self.update_widget(widget_id, "text", **changes)

    def update_widget(self, widget_id: str, settings_key: str, **changes) -> dict:
        self.widgets[widget_id][settings_key].update(changes)
        return self.moblin.update_widget(self.widgets[widget_id])

    def update_scoreboard_generic(self, **changes) -> dict:
        self.widgets[SCOREBOARD_WIDGET_ID]["scoreboard"]["generic"].update(changes)
        return self.moblin.update_widget(self.widgets[SCOREBOARD_WIDGET_ID])

    def add_gray_scale_effect(self, widget_id: str) -> dict:
        widget = self.widgets[widget_id]
        widget["effects"] = widget.get("effects", []) + [{"id": uuid(), "enabled": True, "type": "grayScale"}]
        return self.moblin.update_widget(widget)

    def assert_configuration_steps(
        self,
        recording: Path,
        steps: list[ConfigurationStep],
        step_times: list[float],
    ):
        log_watch_video(recording)
        duration = ffprobe_format(recording).duration
        frozen_periods = find_frozen_periods(recording, duration)
        for start, end in frozen_periods:
            LOGGER.info("Frozen camera from %.3f to %.3f seconds", start, end)
        black_frames = sorted(
            set(find_black_frames(recording, STATIC_WIDGET_CROP, duration))
            | set(find_black_frames(recording, EDITED_WIDGET_CROP, duration))
            | set(find_black_frames(recording, SCOREBOARD_WIDGET_CROP, duration))
        )
        video_source_black_frames = find_black_frames(recording, VIDEO_SOURCE_WIDGET_CROP, duration)
        offset = self.recording_offset(recording, step_times, duration)
        boundaries = [step_time + offset - STEP_MARGIN for step_time in step_times] + [duration]
        violations = []
        if any(pts < boundaries[0] for pts in black_frames + video_source_black_frames):
            violations.append("Widgets flickered before the first configuration step")
        if any(start < boundaries[0] for start, _ in frozen_periods):
            violations.append("Camera reattached before the first configuration step")
        flickered_steps = []
        reattached_steps = []
        for step, start, end in zip(steps, boundaries, boundaries[1:]):
            number_of_missing_frames = sum(1 for pts in black_frames if start <= pts < end)
            number_of_missing_video_source_frames = sum(
                1 for pts in video_source_black_frames if start <= pts < end
            )
            number_of_reattaches = sum(1 for frozen_start, _ in frozen_periods if start <= frozen_start < end)
            LOGGER.info(
                "%s at %.3f seconds: %d frames with missing widgets (allowed %s), %d frames with missing "
                "video source widget, %d camera reattaches (allowed %s)",
                step.name,
                start + STEP_MARGIN,
                number_of_missing_frames,
                step.may_flicker,
                number_of_missing_video_source_frames,
                number_of_reattaches,
                step.may_reattach_camera,
            )
            if number_of_missing_frames > 0:
                flickered_steps.append(step.name)
                if not step.may_flicker:
                    violations.append(f"{step.name}: Widgets flickered")
            if number_of_missing_video_source_frames > 0:
                flickered_steps.append(step.name)
                if not step.may_flicker:
                    violations.append(f"{step.name}: Video source widget flickered")
            if number_of_reattaches > 0:
                reattached_steps.append(step.name)
                if not step.may_reattach_camera:
                    violations.append(f"{step.name}: Camera reattached")
        self.assert_equal(violations, [])
        self.assert_true(len(flickered_steps) > 0, "No flicker detected at all, the detection is broken")
        self.assert_in("Change video source", reattached_steps, "Camera reattach detection is broken")
        self.assert_final_configuration(recording, duration - 1)

    def assert_final_configuration(self, recording: Path, timestamp: float):
        self.assert_equal(read_text_in_video_frame(recording, timestamp, EDITED_TEXT_CROP), "BBBB")
        background = read_video_frame(recording, timestamp, EDITED_WIDGET_CROP).pixel(10, 40)
        self.assert_true(
            background.red > 200 and background.green > 200 and background.blue < 60,
            f"Edited widget background {background} is not yellow",
        )
        self.assert_all_black(read_video_frame(recording, timestamp, MOVER_WIDGET_CROP))
        self.assert_not_all_black(read_video_frame(recording, timestamp, MOVED_MOVER_WIDGET_CROP), 0.5)
        video_source = read_video_frame(recording, timestamp, VIDEO_SOURCE_WIDGET_CROP).pixel(24, 24)
        self.assert_true(
            min(video_source.red, video_source.green, video_source.blue) > 200
            and max(video_source.red, video_source.green, video_source.blue)
            - min(video_source.red, video_source.green, video_source.blue)
            < 20,
            f"Video source widget {video_source} is not the gray scale yellow ingest",
        )
        scoreboard = read_video_frame(recording, timestamp, SCOREBOARD_WIDGET_CROP).pixel(12, 12)
        self.assert_true(
            scoreboard.red > 200 and scoreboard.green < 60 and scoreboard.blue < 60,
            f"Scoreboard background {scoreboard} is not red",
        )

    def recording_offset(self, recording: Path, step_times: list[float], duration: float) -> float:
        hidden = [
            pts for pts in find_black_frames(recording, MOVER_WIDGET_CROP, duration) if pts < step_times[1]
        ]
        self.assert_true(len(hidden) > 0, "The disabled widget never disappeared")
        offset = hidden[0] - step_times[0]
        LOGGER.info("Recording offset: %.3f seconds", offset)
        self.assert_true(-0.5 < offset < 1, f"Recording offset {offset:.3f} seconds")
        return offset


def text_crop(x: int, y: int) -> Crop:
    return Crop(x=x, y=y + 5, width=TEXT_BOX_WIDTH, height=TEXT_BOX_HEIGHT)


def is_white(pixel) -> bool:
    return min(pixel.red, pixel.green, pixel.blue) > 200


@dataclass
class RenderStep:
    description: str
    change: Callable[[], dict]
    checks: list[Callable[[Path, float], str | None]]


class RemoteControlSceneConfigRendering(TestCase):
    """Configure scenes and widgets over remote control and check that every change is rendered."""

    def setup(self):
        self.moblin.import_settings(
            overrides={
                "streams": [RECORD_STREAM_SETTINGS],
                "scenes": [
                    {
                        "id": RENDER_SCENE_ID,
                        "name": "Render",
                        "cameraPosition": CameraPosition.NONE,
                        "enabled": True,
                        "widgets": [],
                    },
                ],
                "widgets": [],
            }
        )
        self.moblin.set_scene_id(RENDER_SCENE_ID)
        self.moblin.wait_for_scene(RENDER_SCENE_ID)

    def run(self):
        self.prepare()
        steps = self.steps()
        step_times = []
        failures = []
        with Recorder(self.moblin, f"{self.name}.mp4") as recorder:
            recording_start = time.monotonic()
            time.sleep(STEP_INTERVAL)
            for step in steps:
                LOGGER.info("Rendering step: %s", step.description)
                step_times.append(time.monotonic() - recording_start)
                result = step.change()
                if "ok" not in result:
                    failures.append(f"{step.description}: expected ok, got {result}")
                time.sleep(STEP_INTERVAL)
            time.sleep(STEP_INTERVAL)
        offset = self.recording_offset(recorder.recording, step_times[0])
        for step, step_time in zip(steps, step_times):
            for check in step.checks:
                failure = check(recorder.recording, step_time + offset + STEP_INTERVAL - STEP_MARGIN)
                if failure is not None:
                    failures.append(f"{step.description}: {failure}")
        for failure in failures:
            LOGGER.info("FAILURE: %s", failure)
        self.assert_equal(failures, [])

    def recording_offset(self, recording: Path, first_step_time: float) -> float:
        frames = read_video_region_colors(recording, Crop(x=0, y=270, width=80, height=80), 1, 1, 0, 30)
        shown = [frame.pts for frame in frames if not frame.colors[0].is_black()]
        self.assert_true(len(shown) > 0, "The first text widget never appeared")
        offset = shown[0] - first_step_time
        LOGGER.info("Recording offset: %.3f seconds", offset)
        self.assert_true(-1 < offset < 1, f"Recording offset {offset:.3f} seconds")
        return offset

    def prepare(self):
        self.assert_in(
            "ok", self.moblin.create_widget(text_widget("Render text", RENDER_TEXT_WIDGET_ID, "AAAA"))
        )
        self.assert_in("ok", self.create_inner_scenes())
        self.assert_in(
            "ok",
            self.moblin.create_widget(
                {
                    "id": NESTED_SCENE_WIDGET_ID,
                    "name": "Nested",
                    "type": WidgetType.SCENE,
                    "enabled": True,
                    "scene": {"sceneId": INNER_SCENE_ID},
                }
            ),
        )
        self.assert_in(
            "ok",
            self.moblin.create_widget(
                {
                    "id": QR_CODE_WIDGET_ID,
                    "name": "QR code",
                    "type": WidgetType.QR_CODE,
                    "enabled": True,
                    "qrCode": {"message": "Moblin"},
                }
            ),
        )

    def text_at(self, x: int, y: int, expected: str) -> Callable[[Path, float], str | None]:
        def check(recording: Path, timestamp: float) -> str | None:
            text = re.sub("[^A-Z]", "", read_text_in_video_frame(recording, timestamp, text_crop(x, y)))
            if text != expected:
                return f"text at ({x}, {y}) is {text!r}, not {expected!r}"
            return None

        return check

    def pixel_at(self, x: int, y: int, name: str, predicate: Callable) -> Callable[[Path, float], str | None]:
        def check(recording: Path, timestamp: float) -> str | None:
            pixel = read_video_frame(recording, timestamp, Crop(x=x, y=y, width=2, height=2)).pixel(0, 0)
            if not predicate(pixel):
                return f"pixel at ({x}, {y}) is {pixel}, not {name}"
            return None

        return check

    def black_at(self, x: int, y: int) -> Callable[[Path, float], str | None]:
        return self.pixel_at(x, y, "black", lambda pixel: pixel.is_black())

    def qr_code_at(self, crop: Crop, expected: str) -> Callable[[Path, float], str | None]:
        def check(recording: Path, timestamp: float) -> str | None:
            message = read_qr_code_in_video_frame(recording, timestamp, crop)
            if message != expected:
                return f"QR code in {crop} is {message!r}, not {expected!r}"
            return None

        return check

    def update_scene(self, scene_id: str, change: Callable[[dict], None]) -> Callable[[], dict]:
        def update() -> dict:
            scene = scenes_by_id(self.moblin)[scene_id]
            change(scene)
            return self.moblin.update_scene(scene)

        return update

    def update_widget(self, widget_id: str, change: Callable[[dict], None]) -> Callable[[], dict]:
        def update() -> dict:
            widget = widgets_by_id(self.moblin)[widget_id]
            change(widget)
            return self.moblin.update_widget(widget)

        return update

    def add_to_scene(
        self, scene_id: str, widget_id: str, x: float, y: float, size: float = 100
    ) -> Callable[[], dict]:
        def add(scene: dict):
            scene["widgets"].append(scene_widget_settings(widget_id, x=x, y=y, size=size))

        return self.update_scene(scene_id, add)

    def create_scene_with_text(self, scene_id: str, name: str, widget_id: str, text: str) -> dict:
        result = self.moblin.create_widget(text_widget(f"{name} text", widget_id, text))
        if "ok" not in result:
            return result
        return self.moblin.create_scene(
            {
                "id": scene_id,
                "name": name,
                "cameraPosition": CameraPosition.NONE,
                "enabled": True,
                "widgets": [scene_widget_settings(widget_id, x=0, y=50, size=100)],
            }
        )

    def create_inner_scenes(self) -> dict:
        result = self.create_scene_with_text(INNER_SCENE_ID, "Inner", INNER_TEXT_WIDGET_ID, "CCCC")
        if "ok" not in result:
            return result
        return self.create_scene_with_text(
            OTHER_INNER_SCENE_ID, "Other inner", OTHER_INNER_TEXT_WIDGET_ID, "DDDD"
        )

    def steps(self) -> list[RenderStep]:
        def set_layout(**layout):
            def change(scene: dict):
                scene["widgets"][0].update(layout)

            return change

        def set_text(format_string: str):
            def change(widget: dict):
                widget["text"]["formatString"] = format_string

            return change

        def show_other_inner_scene(widget: dict):
            widget["scene"]["sceneId"] = OTHER_INNER_SCENE_ID

        def set_qr_code_message(widget: dict):
            widget["qrCode"]["message"] = "Remote"

        qr_code_crop = Crop(x=920, y=500, width=520, height=520)
        return [
            RenderStep(
                "Add text widget to scene",
                self.add_to_scene(RENDER_SCENE_ID, RENDER_TEXT_WIDGET_ID, 0, 25),
                [self.text_at(0, 270, "AAAA")],
            ),
            RenderStep(
                "Align text widget bottom right",
                self.update_scene(RENDER_SCENE_ID, set_layout(x=0, y=0, alignment="BottomRight")),
                [self.pixel_at(1910, 1040, "white", is_white), self.black_at(10, 310)],
            ),
            RenderStep(
                "Add scene widget to scene",
                self.add_to_scene(RENDER_SCENE_ID, NESTED_SCENE_WIDGET_ID, 0, 0),
                [self.text_at(0, 540, "CCCC")],
            ),
            RenderStep(
                "Move widget in nested scene",
                self.update_scene(INNER_SCENE_ID, set_layout(x=50, y=0)),
                [self.text_at(960, 0, "CCCC"), self.black_at(10, 580)],
            ),
            RenderStep(
                "Change text in nested scene",
                self.update_widget(INNER_TEXT_WIDGET_ID, set_text("EEEE")),
                [self.text_at(960, 0, "EEEE")],
            ),
            RenderStep(
                "Show other scene in scene widget",
                self.update_widget(NESTED_SCENE_WIDGET_ID, show_other_inner_scene),
                [self.text_at(0, 540, "DDDD"), self.black_at(970, 40)],
            ),
            RenderStep(
                "Delete widget in nested scene",
                lambda: self.moblin.delete_widget(OTHER_INNER_TEXT_WIDGET_ID),
                [self.black_at(10, 580)],
            ),
            RenderStep(
                "Add QR code widget to scene",
                self.add_to_scene(RENDER_SCENE_ID, QR_CODE_WIDGET_ID, 50, 50, 40),
                [self.qr_code_at(qr_code_crop, "Moblin")],
            ),
            RenderStep(
                "Change QR code message",
                self.update_widget(QR_CODE_WIDGET_ID, set_qr_code_message),
                [self.qr_code_at(qr_code_crop, "Remote")],
            ),
        ]


def tests(moblin: Moblin):
    return [
        RemoteControlSceneConfig(moblin),
        RemoteControlSceneConfigRendering(moblin),
        RemoteControlSceneConfigWhileRecording(moblin),
    ]
