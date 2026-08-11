import json
import zipfile
from enum import StrEnum
from pathlib import Path
from uuid import uuid7

import requests

from .config import WEB_REMOTE_CONTROL_PORT
from .config import Config
from .utils import TEST_DIR

MODELS_BASE_URL = "https://mys-lang.org/moblin-test"
CACHE_DIR = TEST_DIR / "cache"


class SceneName(StrEnum):
    EMPTY = "Empty"
    FRONT = "Front"
    SCREEN = "Screen"


class CameraPosition(StrEnum):
    BACK = "Back"
    FRONT = "Front"
    NONE = "None"
    RIST = "RIST"
    RTMP = "RTMP"
    RTSP = "RTSP"
    SCREEN_CAPTURE = "Screen capture"
    SRTLA = "SRT(LA)"
    SRT_CLIENT = "SRT client"
    WHEP = "WHEP"
    WHIP = "WHIP"


class WidgetType(StrEnum):
    BROWSER = "Browser"
    MAP = "Map"
    PNG_TUBER = "PNGTuber"
    TEXT = "Text"
    VIDEO_SOURCE = "Video source"
    V_TUBER = "VTuber"


class Alignment(StrEnum):
    BOTTOM_LEFT = "BottomLeft"
    BOTTOM_RIGHT = "BottomRight"
    TOP_CENTER = "TopCenter"
    TOP_LEFT = "TopLeft"
    TOP_RIGHT = "TopRight"


class BrowserMode(StrEnum):
    AUDIO_AND_VIDEO_ONLY = "audioAndVideoOnly"
    AUDIO_ONLY = "audioOnly"
    PERIODIC_AUDIO_AND_VIDEO = "periodicAudioAndVideo"


class VideoCodec(StrEnum):
    H264 = "H.264/AVC"
    H265 = "H.265/HEVC"


class AudioCodec(StrEnum):
    AAC = "AAC"
    OPUS = "OPUS"


class BitrateRateControl(StrEnum):
    ABR = "ABR"
    CBR = "CBR"
    VBR = "VBR"


class GraphicsImplementation(StrEnum):
    CORE_IMAGE = "coreImage"
    METAL_PETAL = "metalPetal"


class Resolution(StrEnum):
    FULL_HD = "1920x1080"
    QUAD_HD = "2560x1440"
    ULTRA_HD = "3840x2160"

    def size(self) -> tuple[int, int]:
        width, height = self.split("x")
        return int(width), int(height)


EMPTY_SCENE_SETTINGS = {
    "name": SceneName.EMPTY,
    "cameraPosition": CameraPosition.NONE,
    "enabled": True,
}
FRONT_SCENE_SETTINGS = {
    "name": SceneName.FRONT,
    "cameraPosition": CameraPosition.FRONT,
    "enabled": True,
}
SCREEN_SCENE_SETTINGS = {
    "name": SceneName.SCREEN,
    "cameraPosition": CameraPosition.SCREEN_CAPTURE,
    "enabled": True,
}
RECORD_STREAM_SETTINGS = {
    "enabled": True,
    "fps": 30,
    "resolution": Resolution.FULL_HD,
    "recording": {"videoCodec": VideoCodec.H265},
}


def uuid() -> str:
    return str(uuid7()).upper()


def mic_id(stream_id: str) -> str:
    return f"{stream_id} 0"


def download_model(name: str) -> Path:
    path = CACHE_DIR / name
    if not path.exists():
        url = f"{MODELS_BASE_URL}/{name}"
        print(f"Downloading '{url}'...")
        response = requests.get(url, timeout=60)
        response.raise_for_status()
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_bytes(response.content)
    return path


def scene_widget_settings(
    widget_id: str,
    x: float,
    y: float,
    size: float,
    alignment: Alignment = Alignment.TOP_LEFT,
):
    return {
        "widgetId": widget_id,
        "alignment": alignment,
        "x": x,
        "y": y,
        "size": size,
        "migrated": True,
        "migrated2": True,
    }


def video_source_widget_settings(name: str, widget_id: str, video_source):
    return {
        "id": widget_id,
        "name": name,
        "type": WidgetType.VIDEO_SOURCE,
        "enabled": True,
        "videoSource": video_source,
    }


def text_widget_settings(name: str, widget_id: str, text):
    return {
        "id": widget_id,
        "name": name,
        "type": WidgetType.TEXT,
        "enabled": True,
        "text": text,
    }


def browser_widget_settings(name: str, widget_id: str, url: str, **browser):
    return {
        "id": widget_id,
        "name": name,
        "type": WidgetType.BROWSER,
        "browser": {"url": url, "width": 1920, "height": 1080, **browser},
    }


def base_settings(config: Config):
    return {
        "scenes": [FRONT_SCENE_SETTINGS],
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{config.tester_ip_address()}:{config.remote_control_port()}",
                "reliableChatAndEvents": True,
            },
            "web": {"enabled": True, "port": WEB_REMOTE_CONTROL_PORT},
            "password": "1234",
        },
        "location": {"enabled": True},
        "verboseStatuses": True,
        "showAllSettings": True,
        "debug": {"logLevel": "Debug"},
        "show": {"stream": True, "cpu": True, "microphone": True},
    }


def create_settings_file(settings, output_file: Path, files: dict[str, Path] | None = None):
    with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("settings.json", json.dumps(settings, indent=4))
        for name, path in (files or {}).items():
            archive.write(path, name)
