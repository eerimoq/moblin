import subprocess


class Ffmpeg:
    def __init__(self):
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(["ffmpeg"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()
