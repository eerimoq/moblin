import tomllib
from pathlib import Path
from typing import List


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

    def capabilities(self):
        return self._device()["capabilities"]

    def generic_streams(self) -> List[str]:
        streams = []
        for index in range(len(self.general()["generic-stream-urls"])):
            streams.append(f"Generic {index + 1}")
        return streams

    def _device(self):
        return self._config["device"][self.device_name()]

    def _validate(self, config_toml: Path):
        device_name = self.device_name()
        if device_name not in self._config["device"]:
            raise Exception(
                f"Device '{device_name}' not found in '{config_toml.absolute()}'."
            )
