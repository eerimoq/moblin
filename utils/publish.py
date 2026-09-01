#!/usr/bin/env python3

import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

from termcolor import colored
from yaspin import yaspin
from yaspin.spinners import Spinners

PROJECT = "Moblin.xcodeproj"
SCHEME = "Moblin"
BUILD_PATH = Path("build/publish")

DESTINATIONS = {
    "ios": "generic/platform=iOS",
    "mac": "generic/platform=macOS,variant=Mac Catalyst",
}


def run(description, command):
    with yaspin(Spinners.dots, text=description, color="cyan", timer=True) as spinner:
        try:
            output = subprocess.run(command, capture_output=True, text=True, check=True).stdout
        except subprocess.CalledProcessError as e:
            spinner.fail(colored("✘", "red"))
            print(e.stdout)
            raise
        spinner.ok(colored("✔", "green"))
    return output


def read_setting(path, name):
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        match = re.match(rf"\s*{name}\s*=\s*(\S+)", line)
        if match:
            return match.group(1)
    return sys.exit(f"{name} not found in {path}.")


def write_export_options(path, team_id):
    options = {
        "method": "app-store-connect",
        "destination": "upload",
        "teamID": team_id,
        "signingStyle": "automatic",
        "manageAppVersionAndBuildNumber": True,
        "uploadSymbols": True,
    }
    with open(path, "wb") as fout:
        plistlib.dump(options, fout)


def check_in_app_purchases():
    project = Path(f"{PROJECT}/project.pbxproj").read_text(encoding="utf-8")
    if "StoreKit.framework in Frameworks" not in project:
        sys.exit(
            f"StoreKit.framework is not linked to the {SCHEME} target, so in-app purchases "
            "are not configured."
        )


def create_archive(platform, destination, archive_path):
    run(
        f"Creating {platform} archive",
        [
            "xcodebuild",
            "archive",
            "-project",
            PROJECT,
            "-scheme",
            SCHEME,
            "-configuration",
            "Release",
            "-destination",
            destination,
            "-archivePath",
            str(archive_path),
            "-allowProvisioningUpdates",
        ],
    )


def upload_archive(platform, archive_path, export_options_path, export_path):
    return run(
        f"Uploading {platform} archive to App Store Connect",
        [
            "xcodebuild",
            "-exportArchive",
            "-archivePath",
            str(archive_path),
            "-exportOptionsPlist",
            str(export_options_path),
            "-exportPath",
            str(export_path),
            "-allowProvisioningUpdates",
        ],
    )


def find_build_number(archive_path):
    info = plistlib.loads((archive_path / "Info.plist").read_bytes())
    for distribution in reversed(info.get("Distributions", [])):
        if distribution.get("uploadEvent", {}).get("state") == "success":
            return distribution.get("uploadedBuildNumber")
    return None


def create_tag(platform, version, build_number):
    tag = f"{platform}-{version}-{build_number}"
    run(f"Creating tag {tag}", ["git", "tag", tag])


def archive(platform, destination, work_path):
    archive_path = work_path / f"{SCHEME}.xcarchive"
    create_archive(platform, destination, archive_path)
    return archive_path


def publish(platform, archive_path, work_path, export_options_path):
    export_path = work_path / "export"
    upload_archive(platform, archive_path, export_options_path, export_path)
    build_number = find_build_number(archive_path)
    if build_number is None:
        sys.exit("Uploaded, but could not find the build number assigned by App Store Connect.")
    return build_number


def main():
    check_in_app_purchases()
    version = read_setting("Config/Base.xcconfig", "MARKETING_VERSION")
    team_id = read_setting("Config/User.xcconfig", "DEVELOPMENT_TEAM")
    shutil.rmtree(BUILD_PATH, ignore_errors=True)
    BUILD_PATH.mkdir(parents=True)
    export_options_path = BUILD_PATH / "ExportOptions.plist"
    write_export_options(export_options_path, team_id)
    for platform, destination in DESTINATIONS.items():
        work_path = BUILD_PATH / platform
        work_path.mkdir(parents=True)
        archive_path = archive(platform, destination, work_path)
        build_number = publish(platform, archive_path, work_path, export_options_path)
        create_tag(platform, version, build_number)


main()
