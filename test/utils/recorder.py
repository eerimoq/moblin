from pathlib import Path

from .moblin import Moblin


class Recorder:
    def __init__(self, moblin: Moblin, filename: str):
        self.recording = Path()
        self._moblin = moblin
        self._filename = filename

    def __enter__(self):
        self._moblin.start_recording()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._moblin.stop_recording()
        self.recording = self._moblin.download_and_delete_latest_recording(
            self._filename
        )
