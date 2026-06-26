import argparse
import json
from pathlib import Path
import tomllib


def create_settings(config):
    general = config["general"]
    tester_ip_address = general["tester-ip-address"]
    return {
        "streams": [
            {
                "url": f"rtmp://{tester_ip_address}:1935/test",
                "name": "RTMP",
                "enabled": True,
                "rtmp": {
                    "adaptiveBitrateEnabled": False
                }
            },
            {
                "url": f"srt://{tester_ip_address}:8890?streamid=publish:test",
                "name": "SRT",
                "srt": {
                    "adaptiveBitrateEnabled": False
                }
            },
        ],
        "scenes": [{"name": "Front", "cameraPosition": "Front", "enabled": True}],
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{tester_ip_address}:{general["remote-control-port"]}",
            },
            "password": general["remote-control-password"],
        },
        "verboseStatuses": True,
        "showAllSettings": True,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    args = parser.parse_args()
    config = tomllib.loads(args.config_toml.read_text())
    settings = create_settings(config)
    with open(f"{config["general"]["device"]}-settings.json", "w") as fout:
        fout.write(json.dumps(settings, indent=4))


main()
