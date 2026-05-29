import subprocess


class MediaMtx:
    def __init__(self):
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(["mediamtx"])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._server.kill()
