import argparse
import json
from pathlib import Path

import pyperclip

from utils.generate_device_settings import base_settings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-stdout", action="store_true")
    parser.add_argument("config_toml", type=Path)
    args = parser.parse_args()
    settings = json.dumps(base_settings(args.config_toml), indent=4)
    if args.force_stdout:
        print(settings)
    else:
        pyperclip.copy(settings)
        print("Settings copied to clipboard.")


main()
