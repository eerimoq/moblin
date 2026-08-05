import argparse
from pathlib import Path

from utils.generate_device_settings import generate_initial_settings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config_toml", type=Path)
    args = parser.parse_args()
    output_file = Path("device.moblinSettings")
    generate_initial_settings(args.config_toml, output_file)
    print(f"Settings written to '{output_file.absolute()}'.")


main()
