import logging
import re
import subprocess
from pathlib import Path

from .ffmpeg import file_size
from .process import ManagedProcess
from .utils import wait_until

LOGGER = logging.getLogger(__name__)

SNAPSHOT_LENGTH = 128


class NetworkCapture:
    def __init__(self, hosts: list[str], directory: Path, name: str):
        self._hosts = hosts
        self._directory = directory
        self._name = name
        self._processes: list[ManagedProcess] = []
        self.files: list[Path] = []

    def __enter__(self):
        try:
            for interface in sorted({find_interface(host) for host in self._hosts}):
                self._start(interface)
        except BaseException:
            self.stop()
            raise
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()

    def poll(self):
        for process in [process for process in self._processes if not process.is_running()]:
            LOGGER.warning("A network capture exited. No longer capturing all packets.")
            self._processes.remove(process)

    def stop(self):
        for process in self._processes:
            process.stop()
        self._processes = []
        for file in self.files:
            LOGGER.info("Captured %.1f MB of packets to %s.", file_size(file) / 1e6, file)

    def _start(self, interface: str):
        file = self._directory / f"{self._name}-{interface}.pcap"
        command = [
            "tcpdump",
            "-i",
            interface,
            "-s",
            str(SNAPSHOT_LENGTH),
            "-p",
            "-U",
            "-w",
            str(file),
            " or ".join(f"host {host}" for host in self._hosts),
        ]
        process = ManagedProcess(command, LOGGER)
        process.start()
        self._processes.append(process)
        self.files.append(file)
        wait_until(
            lambda: capture_is_started(process, file),
            f"the network capture on {interface} to start",
        )
        LOGGER.info("Capturing packets on %s to %s.", interface, file)


def capture_is_started(process: ManagedProcess, file: Path) -> bool:
    if not process.is_running():
        raise Exception(f"tcpdump exited. Is capturing to '{file}' allowed?")
    return file.exists()


def find_interface(host: str) -> str:
    output = subprocess.run(
        ["route", "-n", "get", host],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    match = re.search(r"^\s*interface:\s*(\S+)$", output, re.MULTILINE)
    if match is None:
        raise Exception(f"No network interface found for '{host}'.")
    return match.group(1)
