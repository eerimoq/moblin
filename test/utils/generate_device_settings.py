import json
import zipfile
from pathlib import Path
from typing import Dict

import requests

from utils.config import RIST_SERVER_PORT
from utils.config import RTMP_SERVER_PORT
from utils.config import SRT_CLIENT_1_SERVER_PORT
from utils.config import SRT_CLIENT_TALKBACK_SERVER_PORT
from utils.config import SRT_SERVER_PORT
from utils.config import WEB_REMOTE_CONTROL_PORT
from utils.config import Config

RTMP_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1385"
RTMP_TALKBACK_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1386"
RTSP_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1387"
RIST_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1388"
SRT_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1389"
SRT_TALKBACK_STREAM_ID = "F3868489-D301-422D-A7DD-135572CA1389"
SRT_CLIENT_STREAM_ID = "F3868489-D301-422D-A7DD-334572CA1387"
SRT_CLIENT_TALKBACK_STREAM_ID = "F3868489-D301-522D-A7DD-135572CA1389"
BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID = "F3868489-D301-422D-A7DD-335572CA1312"
BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1313"
BROWSER_WIDGET_AUDIO_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1314"
BROWSER_WIDGET_LOCAL_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1315"
PNG_TUBER_MODEL_ID = "F3868489-D301-422D-A7DD-335572CA1320"
V_TUBER_MODEL_ID = "F3868489-D301-422D-A7DD-335572CA1321"
V_TUBER_MODEL_NAME = "AliciaSolid.vrm"
PNG_TUBER_MODEL_NAME = "moblin.save"
MODELS_BASE_URL = "https://mys-lang.org/moblin-test"
CACHE_DIR = Path("cache")


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


def create_streams_settings(config: Config):
    streams = [
        {
            "name": "RTMP",
            "enabled": True,
            "bitrateRateControl": "CBR",
            "url": f"rtmp://{config.tester_ip_address()}:1935/test",
            "rtmp": {"adaptiveBitrateEnabled": False},
        },
        {"name": "Record H.264 1920x1080@30", "recording": {"videoCodec": "H.264/AVC"}},
    ]
    for resolution in ["1920x1080", "2560x1440", "3840x2160"]:
        for fps in [30, 60]:
            streams.append(
                {
                    "name": f"Record H.265 {resolution}@{fps}",
                    "fps": fps,
                    "resolution": resolution,
                    "recording": {"videoCodec": "H.265/HEVC"},
                }
            )
    return streams


def create_scenes_settings():
    return [
        {"name": "Front", "cameraPosition": "Front", "enabled": True},
        {
            "name": "RTMP server ingest",
            "cameraPosition": "RTMP",
            "rtmpCameraId": RTMP_STREAM_ID,
            "enabled": True,
            "overrideMic": True,
            "micId": f"{RTMP_STREAM_ID} 0",
        },
        {
            "name": "RTSP client ingest",
            "cameraPosition": "RTSP",
            "rtspCameraId": RTSP_STREAM_ID,
            "enabled": True,
            "overrideMic": True,
            "micId": f"{RTSP_STREAM_ID} 0",
        },
        {
            "name": "RIST server ingest",
            "cameraPosition": "RIST",
            "ristCameraId": RIST_STREAM_ID,
            "enabled": True,
            "overrideMic": True,
            "micId": f"{RIST_STREAM_ID} 0",
        },
        {
            "name": "SRT server ingest",
            "cameraPosition": "SRT(LA)",
            "srtlaCameraId": SRT_STREAM_ID,
            "enabled": True,
            "overrideMic": True,
            "micId": f"{SRT_STREAM_ID} 0",
        },
        {
            "name": "SRT client ingest",
            "cameraPosition": "SRT client",
            "srtClientCameraId": SRT_CLIENT_STREAM_ID,
            "enabled": True,
            "overrideMic": True,
            "micId": f"{SRT_CLIENT_STREAM_ID} 0",
        },
        {
            "name": "Browser widgets",
            "cameraPosition": "Screen capture",
            "widgets": [
                {
                    "widgetId": BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID,
                    "alignment": "TopLeft",
                    "x": 0,
                    "y": 0,
                    "size": 100,
                    "migrated": True,
                    "migrated2": True,
                },
                {
                    "widgetId": BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID,
                    "alignment": "TopLeft",
                    "x": 50,
                    "y": 0,
                    "size": 100,
                    "migrated": True,
                    "migrated2": True,
                },
                {
                    "widgetId": BROWSER_WIDGET_AUDIO_ONLY_ID,
                    "alignment": "TopLeft",
                    "x": 0,
                    "y": 50,
                    "size": 100,
                    "migrated": True,
                    "migrated2": True,
                },
                {
                    "widgetId": BROWSER_WIDGET_LOCAL_ONLY_ID,
                    "alignment": "TopLeft",
                    "x": 50,
                    "y": 50,
                    "size": 100,
                    "migrated": True,
                    "migrated2": True,
                },
            ],
            "enabled": True,
        },
    ]


def create_widgets_settings(config: Config):
    return [
        {
            "id": BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID,
            "name": "Browser periodic audio and video",
            "type": "Browser",
            "browser": {
                "url": f"http://{config.tester_ip_address()}:6967/BrowserWidgetHighFpsVideo.html",
                "width": 1920,
                "height": 1080,
                "mode": "periodicAudioAndVideo",
            },
        },
        {
            "id": BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID,
            "name": "Browser audio and video only",
            "type": "Browser",
            "browser": {
                "url": f"http://{config.tester_ip_address()}:6967/BrowserWidgetHighFpsVideo.html",
                "width": 1920,
                "height": 1080,
                "mode": "audioAndVideoOnly",
            },
        },
        {
            "id": BROWSER_WIDGET_AUDIO_ONLY_ID,
            "name": "Browser audio only",
            "type": "Browser",
            "browser": {
                "url": f"http://{config.tester_ip_address()}:6967/BrowserWidgetHighFpsVideo.html",
                "width": 1920,
                "height": 1080,
                "mode": "audioOnly",
            },
        },
        {
            "id": BROWSER_WIDGET_LOCAL_ONLY_ID,
            "name": "Browser local only",
            "type": "Browser",
            "browser": {
                "url": f"http://{config.tester_ip_address()}:6967/BrowserWidgetHighFpsVideo.html",
                "width": 1920,
                "height": 1080,
                "localOnly": True,
            },
        },
    ]


def create_settings(config: Config):
    return {
        "streams": create_streams_settings(config),
        "scenes": create_scenes_settings(),
        "widgets": create_widgets_settings(config),
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{config.tester_ip_address()}:{config.remote_control_port()}",
            },
            "web": {"enabled": True, "port": WEB_REMOTE_CONTROL_PORT},
            "password": "1234",
        },
        "rtmpServer": {
            "enabled": True,
            "port": RTMP_SERVER_PORT,
            "streams": [
                {"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"},
                {
                    "id": RTMP_TALKBACK_STREAM_ID,
                    "name": "Talkback",
                    "streamKey": "talkback",
                },
            ],
        },
        "srtlaServer": {
            "enabled": True,
            "srtPort": SRT_SERVER_PORT,
            "streams": [
                {
                    "id": SRT_STREAM_ID,
                    "name": "Test",
                    "streamId": "1",
                },
                {
                    "id": SRT_TALKBACK_STREAM_ID,
                    "name": "Talkback",
                    "streamId": "talkback",
                },
            ],
        },
        "rtspClient": {
            "streams": [
                {
                    "id": RTSP_STREAM_ID,
                    "name": "1",
                    "url": f"rtsp://{config.tester_ip_address()}:8554/1",
                    "enabled": True,
                },
            ],
        },
        "ristServer": {
            "enabled": True,
            "port": RIST_SERVER_PORT,
            "streams": [
                {"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 1}
            ],
        },
        "srtClient": {
            "streams": [
                {
                    "id": SRT_CLIENT_STREAM_ID,
                    "name": "1",
                    "url": f"srt://{config.tester_ip_address()}:{SRT_CLIENT_1_SERVER_PORT}",
                    "enabled": True,
                },
                {
                    "id": SRT_CLIENT_TALKBACK_STREAM_ID,
                    "name": "Talkback",
                    "url": f"srt://{config.tester_ip_address()}:{SRT_CLIENT_TALKBACK_SERVER_PORT}",
                    "enabled": True,
                },
            ],
        },
        "talkBack": {"enabled": True, "micId": f"{RTMP_TALKBACK_STREAM_ID} 0"},
        "location": {"enabled": True},
        "verboseStatuses": True,
        "showAllSettings": True,
        "debug": {"logLevel": "Debug"},
        "show": {"stream": True, "cpu": True, "microphone": True},
    }


def base_settings(config_toml: Path):
    return create_settings(Config(config_toml, ""))


def create_settings_file(
    settings, output_file: Path, files: Dict[str, Path] | None = None
):
    with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("settings.json", json.dumps(settings, indent=4))
        for name, path in (files or {}).items():
            archive.write(path, name)


def generate_initial_settings(config_toml: Path, output_file: Path):
    settings = create_settings(Config(config_toml, ""))
    files = v_tuber_model_files() | png_tuber_model_files()
    create_settings_file(settings, output_file, files)
