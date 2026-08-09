import json
import zipfile
from pathlib import Path
from uuid import uuid7

import requests

from utils.config import WEB_REMOTE_CONTROL_PORT
from utils.config import Config
from utils.utils import TEST_DIR

MODELS_BASE_URL = "https://mys-lang.org/moblin-test"
CACHE_DIR = TEST_DIR / "cache"
FRONT_SCENE_SETTINGS = {"name": "Front", "cameraPosition": "Front", "enabled": True}
RECORD_STREAM_SETTINGS = {
    "enabled": True,
    "fps": 30,
    "resolution": "1920x1080",
    "recording": {"videoCodec": "H.265/HEVC"},
}


def uuid() -> str:
    return str(uuid7()).upper()


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
    widget_id: str, x: int, y: int, size: int, alignment: str = "TopLeft"
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
        "type": "Video source",
        "enabled": True,
        "videoSource": video_source,
    }


def base_settings(config_toml: Path):
    config = Config(config_toml, "")
    return {
        "scenes": [FRONT_SCENE_SETTINGS],
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{config.tester_ip_address()}:{config.remote_control_port()}",
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


def create_settings_file(
    settings, output_file: Path, files: dict[str, Path] | None = None
):
    with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("settings.json", json.dumps(settings, indent=4))
        for name, path in (files or {}).items():
            archive.write(path, name)
