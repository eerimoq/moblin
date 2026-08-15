import tomllib
from enum import StrEnum
from pathlib import Path

from xdg_base_dirs import xdg_config_home

from .utils import TEST_DIR

# Ports served by Moblin on the device.
WEB_REMOTE_CONTROL_PORT = 1180
RTMP_SERVER_PORT = 11935
SRT_SERVER_PORT = 4000
RIST_SERVER_PORT = 6500
WHIP_SERVER_PORT = 8310
# Ports served on the tester machine.
SRT_CLIENT_1_SERVER_PORT = 4004
SRT_CLIENT_TALKBACK_SERVER_PORT = 4005
SRT_CLIENT_2_SERVER_PORT = 4006
SRT_CLIENT_STABILITY_SERVER_PORT = 4007
TESTER_RIST_PORT = 6600
TESTER_RTMP_PORT = 1935
TESTER_RTSP_PORT = 8554
TESTER_SRT_PORT = 8890
TESTER_WEBRTC_PORT = 8889
TESTER_WEBRTC_UDP_PORT = 8189
MEDIAMTX_API_PORT = 9997
WEB_SERVER_PORT = 6967

REMOTE_CONTROL_PASSWORD = "1234"


class Capability(StrEnum):
    PIP = "pip"
    RECORD = "record"
    BACKGROUND_STREAMING = "background-streaming"


def srt_listener_url(
    port: int = TESTER_SRT_PORT,
    stream_id: str | None = None,
    passphrase: str | None = None,
) -> str:
    url = f"srt://0.0.0.0:{port}?mode=listener"
    if stream_id is not None:
        url += f"&streamid={stream_id}"
    if passphrase is not None:
        url += f"&passphrase={passphrase}"
    return url


def srt_reader_url(path: str, port: int = TESTER_SRT_PORT) -> str:
    return f"srt://localhost:{port}?streamid=read:{path}"


def rtsp_reader_url(path: str, port: int = TESTER_RTSP_PORT) -> str:
    return f"rtsp://localhost:{port}/{path}"


def rist_listener_url(port: int = TESTER_RIST_PORT) -> str:
    return f"rist://@0.0.0.0:{port}"


def find_config_toml() -> Path:
    paths = [TEST_DIR / "config.toml", xdg_config_home() / "moblin" / "tests" / "config.toml"]
    for path in paths:
        if path.exists():
            return path
    found = " or ".join(f"'{path}'" for path in paths)
    raise Exception(f"No configuration file found. Create {found}.")


class Config:
    def __init__(self, device: str):
        self.config_toml = find_config_toml()
        self._config = tomllib.loads(self.config_toml.read_text())
        if device:
            self.general()["device"] = device
        self._validate(self.config_toml)

    def device_name(self):
        return self.general()["device"]

    def general(self):
        return self._config["general"]

    def remote_control_port(self):
        return self.general()["remote-control-port"]

    def moblin_ip_address(self):
        return self._device()["moblin-ip-address"]

    def tester_ip_address(self):
        return self.general()["tester-ip-address"]

    def capabilities(self):
        return self._device()["capabilities"]

    def generic_stream_urls(self) -> list[str]:
        return self.general()["generic-stream-urls"]

    def shaper(self):
        shaper = self._config.get("shaper")
        if shaper is None:
            raise Exception(f"No [shaper] section found in '{self.config_toml.absolute()}'.")
        return shaper

    def _device(self):
        return self._config["device"][self.device_name()]

    def _validate(self, config_toml: Path):
        device_name = self.device_name()
        if device_name not in self._config["device"]:
            raise Exception(f"Device '{device_name}' not found in '{config_toml.absolute()}'.")
