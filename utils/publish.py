#!/usr/bin/env python3

import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = "Moblin.xcodeproj"
SCHEME = "Moblin"
BUILD_PATH = Path("build/publish")

DESTINATIONS = {
    "ios": "generic/platform=iOS",
    "mac": "generic/platform=macOS,variant=Mac Catalyst",
}


def run(command):
    print(" ".join(command))
    try:
        return subprocess.run(command, capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError as e:
        print(e.stdout)
        raise


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


def create_archive(destination, archive_path):
    run(
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
        ]
    )


def upload_archive(archive_path, export_options_path, export_path):
    return run(
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
        ]
    )


def find_build_number(archive_path):
    info = plistlib.loads((archive_path / "Info.plist").read_bytes())
    for distribution in reversed(info.get("Distributions", [])):
        if distribution.get("uploadEvent", {}).get("state") == "success":
            return distribution.get("uploadedBuildNumber")
    return None


def create_tag(platform, version, build_number):
    run(["git", "tag", f"{platform}-{version}-{build_number}"])


def archive(destination, work_path):
    archive_path = work_path / f"{SCHEME}.xcarchive"
    create_archive(destination, archive_path)
    return archive_path


def publish(archive_path, work_path, export_options_path):
    export_path = work_path / "export"
    upload_archive(archive_path, export_options_path, export_path)
    build_number = find_build_number(archive_path)
    if build_number is None:
        sys.exit("Uploaded, but could not find the build number assigned by App Store Connect.")
    return build_number


def main():
    version = read_setting("Config/Base.xcconfig", "MARKETING_VERSION")
    team_id = read_setting("Config/User.xcconfig", "DEVELOPMENT_TEAM")
    shutil.rmtree(BUILD_PATH, ignore_errors=True)
    BUILD_PATH.mkdir(parents=True)
    export_options_path = BUILD_PATH / "ExportOptions.plist"
    write_export_options(export_options_path, team_id)
    for platform, destination in DESTINATIONS.items():
        work_path = BUILD_PATH / platform
        work_path.mkdir(parents=True)
        archive_path = archive(destination, work_path)
        build_number = publish(archive_path, work_path, export_options_path)
        create_tag(platform, version, build_number)


main()
