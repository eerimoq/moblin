import logging
from pathlib import Path
from types import TracebackType
from typing import Self

from systest import ManagedProcess

LOGGER = logging.getLogger(__name__)


class WebServer:
    def __init__(self, port: int, static_root: Path) -> None:
        self._server = ManagedProcess(["python", "-m", "http.server", str(port)], LOGGER, cwd=static_root)

    def __enter__(self) -> Self:
        self._server.start()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> None:
        self._server.stop()
