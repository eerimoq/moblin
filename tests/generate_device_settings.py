import argparse
import json

import pyperclip

from utils.config import Config
from utils.generate_device_settings import base_settings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-stdout", action="store_true")
    args = parser.parse_args()
    settings = json.dumps(base_settings(Config("")), indent=4)
    if args.force_stdout:
        print(settings)
    else:
        pyperclip.copy(settings)
        print("Settings copied to clipboard.")


main()
