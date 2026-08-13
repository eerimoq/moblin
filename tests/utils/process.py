import logging
import subprocess
import threading
from collections.abc import Callable
from logging import Logger
from pathlib import Path


def _log_stream(stream, logger: Logger, log_level, observer):
    try:
        for line in stream:
            line = line.rstrip()
            logger.log(log_level(line), line)
            if observer is not None:
                observer(line)
    except Exception:
        pass


def _log_level(_line: str) -> int:
    return logging.DEBUG


def log_output(stream, logger, log_level=_log_level, observer=None):
    threading.Thread(target=_log_stream, args=(stream, logger, log_level, observer), daemon=True).start()


class ManagedProcess:
    def __init__(
        self,
        command: list[str],
        logger: Logger,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
        stdin: int | None = None,
        log_level: Callable[[str], int] = _log_level,
        observer: Callable[[str], None] | None = None,
        ready: Callable[[], None] | None = None,
    ):
        self._command = command
        self._logger = logger
        self._cwd = cwd
        self._env = env
        self._stdin = stdin
        self._log_level = log_level
        self._observer = observer
        self._ready = ready
        self._process: subprocess.Popen | None = None

    def start(self):
        self._logger.debug("Command: %s", " ".join(self._command))
        self._process = subprocess.Popen(
            self._command,
            cwd=self._cwd,
            env=self._env,
            stdin=self._stdin,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._process.stdout, self._logger, self._log_level, self._observer)
        log_output(self._process.stderr, self._logger, self._log_level)
        if self._ready is not None:
            try:
                self._ready()
            except BaseException:
                self.stop()
                raise

    def stop(self):
        if self._process is not None:
            self._process.kill()
            self._process.wait()
            self._process = None

    def is_running(self) -> bool:
        return self._process is not None and self._process.poll() is None

    def pid(self) -> int | None:
        if self._process is None:
            return None
        return self._process.pid

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()
