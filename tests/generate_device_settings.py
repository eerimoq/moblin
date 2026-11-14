import argparse
import json

import pyperclip

from .utils.config import Config
from .utils.generate_device_settings import base_settings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-stdout", action="store_true")
    parser.add_argument(
        "--receiver",
        action="store_true",
        help="Generate settings for the SRTLA receiver on the tester machine.",
    )
    args = parser.parse_args()
    config = Config()
    if args.receiver:
        remote_control_port = config.receiver_remote_control_port()
    else:
        remote_control_port = config.remote_control_port()
    settings = json.dumps(base_settings(config, remote_control_port), indent=4)
    if args.force_stdout:
        print(settings)
    else:
        pyperclip.copy(settings)
        print("Settings copied to clipboard.")


main()
