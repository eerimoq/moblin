import tomllib
from pathlib import Path
from typing import List

from utils.utils import format_generic_stream_url_stream_name

WEB_REMOTE_CONTROL_PORT = 1180
RTMP_SERVER_PORT = 11935
SRT_SERVER_PORT = 4000
RIST_SERVER_PORT = 6500


class Config:
    def __init__(self, config_toml: Path, device: str):
        self._config = tomllib.loads(config_toml.read_text())
        if device:
            self.general()["device"] = device
        self._validate(config_toml)

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

    def generic_streams(self) -> List[str]:
        streams = []
        generic_stream_urls = self.general()["generic-stream-urls"]
        for number, generic_stream_url in enumerate(generic_stream_urls, 1):
            streams.append(
                format_generic_stream_url_stream_name(number, generic_stream_url)
            )
        return streams

    def _device(self):
        return self._config["device"][self.device_name()]

    def _validate(self, config_toml: Path):
        device_name = self.device_name()
        if device_name not in self._config["device"]:
            raise Exception(
                f"Device '{device_name}' not found in '{config_toml.absolute()}'."
            )
