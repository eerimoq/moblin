import subprocess


class Ffmpeg:
    def __init__(self, url):
        self._url = url
        self._server = None

    def __enter__(self):
        self._server = subprocess.Popen(["ffmpeg", "-re", "-i", "video.mp4", self._url])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._server is not None:
            self._server.kill()
            self._server.wait()
