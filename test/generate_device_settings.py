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
                "name": "RTMP",
                "enabled": True,
                "url": f"rtmp://{tester_ip_address}:1935/test",
                "rtmp": {"adaptiveBitrateEnabled": False},
            },
            {
                "name": "SRT",
                "url": f"srt://{tester_ip_address}:8890?streamid=publish:test",
                "srt": {"adaptiveBitrateEnabled": False},
                "bitrate": 50_000_000,
            },
            {
                "name": "Multi RTMP",
                "enabled": True,
                "url": f"rtmp://{tester_ip_address}:1935/test1",
                "rtmp": {"adaptiveBitrateEnabled": False},
                "multiStreaming": {
                    "destinations": [
                        {
                            "name": "Test 2",
                            "url": f"rtmp://{tester_ip_address}:1935/test2",
                            "enabled": True,
                        },
                        {
                            "name": "Test 3",
                            "url": f"rtmp://{tester_ip_address}:1935/test3",
                            "enabled": True,
                        },
                    ]
                },
            },
        ],
        "scenes": [
            {"name": "Front", "cameraPosition": "Front", "enabled": True},
            {"name": "Screen", "cameraPosition": "Screen capture", "enabled": True},
        ],
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{tester_ip_address}:{general["remote-control-port"]}",
            },
            "password": general["remote-control-password"],
        },
        "rtmpServer": {"enabled": True, "port": 11935, "streams": [{"streamKey": "1"}]},
        "verboseStatuses": True,
        "showAllSettings": True,
        "show": {"cpu": True},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    args = parser.parse_args()
    config = tomllib.loads(args.config_toml.read_text())
    settings = create_settings(config)
    Path(f"{config["general"]["device"]}-settings.json").write_text(
        json.dumps(settings, indent=4), encoding="utf-8"
    )


main()
