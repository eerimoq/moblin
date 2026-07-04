import shutil
import sys

from . import ffmpeg


def _is_executable_in_path(name: str) -> bool:
    return shutil.which(name) is not None


def check_dependencies():
    missing_dependencies = []
    for executable in ["ffmpeg", "qrtool", "mediamtx"]:
        if not _is_executable_in_path(executable):
            missing_dependencies.append(f"{executable} executable not found")
    missing_dependencies += ffmpeg.check_dependencies()
    if len(missing_dependencies) > 0:
        print("--- Missing dependencies ---")
        print()
        for missing_dependency in missing_dependencies:
            print("  -", missing_dependency)
        print()
        sys.exit(1)
