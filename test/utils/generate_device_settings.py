import json
import zipfile
from pathlib import Path
from typing import Dict

import requests

from utils.config import WEB_REMOTE_CONTROL_PORT
from utils.config import Config

PNG_TUBER_MODEL_ID = "F3868489-D301-422D-A7DD-335572CA1320"
V_TUBER_MODEL_ID = "F3868489-D301-422D-A7DD-335572CA1321"
V_TUBER_MODEL_NAME = "AliciaSolid.vrm"
PNG_TUBER_MODEL_NAME = "moblin.save"
MODELS_BASE_URL = "https://mys-lang.org/moblin-test"
CACHE_DIR = Path("cache")
FRONT_SCENE_SETTINGS = {"name": "Front", "cameraPosition": "Front", "enabled": True}
RECORD_STREAM_SETTINGS = {
    "enabled": True,
    "fps": 30,
    "resolution": "1920x1080",
    "recording": {"videoCodec": "H.265/HEVC"},
}


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


def png_tuber_model_files() -> Dict[str, Path]:
    """The PNGTuber model, as stored in a settings file."""

    return {f"PNGTuber/{PNG_TUBER_MODEL_ID}": download_model(PNG_TUBER_MODEL_NAME)}


def v_tuber_model_files() -> Dict[str, Path]:
    """The VTuber model, as stored in a settings file."""

    return {f"VTuber/{V_TUBER_MODEL_ID}": download_model(V_TUBER_MODEL_NAME)}


def base_settings(config_toml: Path):
    config = Config(config_toml, "")
    return {
        "streams": [],
        "scenes": [FRONT_SCENE_SETTINGS],
        "widgets": [],
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
    settings, output_file: Path, files: Dict[str, Path] | None = None
):
    with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("settings.json", json.dumps(settings, indent=4))
        for name, path in (files or {}).items():
            archive.write(path, name)


def generate_initial_settings(config_toml: Path, output_file: Path):
    create_settings_file(base_settings(config_toml), output_file)
