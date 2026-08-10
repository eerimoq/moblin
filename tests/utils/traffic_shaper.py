import logging
import math
import os
import random
import shutil
import subprocess
import tempfile
import threading
import time
from collections import deque
from dataclasses import dataclass
from dataclasses import replace
from pathlib import Path

from .config import Config
from .utils import log_output

LOGGER = logging.getLogger(__name__)
STREAM_GROUP = "stream"
INGESTS_GROUP = "ingests"
TESTER_SIDE = "tester"
DEVICE_SIDE = "device"
TCP = "tcp"
UDP = "udp"
PROTOCOL_NUMBERS = {TCP: 6, UDP: 17}
GROUP_CLASS_IDS = {STREAM_GROUP: 10, INGESTS_GROUP: 20}
DEFAULT_CLASS_ID = 30
ROOT_RATE = "10gbit"
DEFAULT_LIMIT = 1000
RELAY_TIMEOUT = 600
READY_TIMEOUT = 30
CONTROL_MASTER_TIMEOUT = 30
EXECUTE_TIMEOUT = 30
SESSION_OUTPUT_LINES = 20
BITRATE_SUFFIXES = {
    "bit": 1,
    "kbit": 1_000,
    "mbit": 1_000_000,
    "gbit": 1_000_000_000,
}
DEFAULT_SQUARE_PERIOD = 60.0
DEFAULT_RANDOM_INTERVAL = 15.0
CONSTANT_PROFILE = "constant"
SQUARE_PROFILE = "square"
RANDOM_PROFILE = "random"
PROFILES = [CONSTANT_PROFILE, SQUARE_PROFILE, RANDOM_PROFILE]
SSH_OPTIONS = [
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "ServerAliveInterval=15",
    "-o",
    "ServerAliveCountMax=3",
]


@dataclass
class Relay:
    group: str
    protocol: str
    port: int
    side: str


@dataclass
class Impairment:
    rate: int | None = None
    delay_ms: float = 0
    jitter_ms: float = 0
    loss_percent: float = 0
    limit: int = DEFAULT_LIMIT

    def netem_arguments(self) -> str:
        arguments = ["limit", str(self.limit)]
        if self.delay_ms > 0:
            arguments += ["delay", f"{self.delay_ms}ms"]
            if self.jitter_ms > 0:
                arguments += [f"{self.jitter_ms}ms", "distribution", "normal"]
        if self.loss_percent > 0:
            arguments += ["loss", f"{self.loss_percent}%"]
        if self.rate is not None:
            arguments += ["rate", f"{self.rate}bit"]
        return " ".join(arguments)

    def __str__(self):
        parts = []
        if self.rate is not None:
            parts.append(f"{self.rate / 1e6:.1f} Mbps")
        if self.delay_ms > 0:
            delay = f"{self.delay_ms:.0f} ms"
            if self.jitter_ms > 0:
                delay += f" +- {self.jitter_ms:.0f} ms"
            parts.append(delay)
        if self.loss_percent > 0:
            parts.append(f"{self.loss_percent} % loss")
        if len(parts) == 0:
            return "no impairment"
        return ", ".join(parts)


class Profile:
    def __init__(self):
        self._next_time: float | None = None

    def poll(self, now: float) -> Impairment | None:
        if self._next_time is not None and now < self._next_time:
            return None
        self._next_time = now + self.change_period_or_forever()
        return self.create_impairment()

    def create_impairment(self) -> Impairment:
        raise NotImplementedError()

    def change_period(self) -> float:
        raise NotImplementedError()

    def change_period_or_forever(self) -> float:
        period = self.change_period()
        if period <= 0:
            return math.inf
        return period

    def minimum_rate(self) -> int | None:
        raise NotImplementedError()

    def maximum_rate(self) -> int | None:
        raise NotImplementedError()


class ConstantProfile(Profile):
    def __init__(self, impairment: Impairment):
        super().__init__()
        self._impairment = impairment

    def create_impairment(self) -> Impairment:
        return self._impairment

    def change_period(self) -> float:
        return 0

    def minimum_rate(self) -> int | None:
        return self._impairment.rate

    def maximum_rate(self) -> int | None:
        return self._impairment.rate

    def __str__(self):
        return f"constant ({self._impairment})"


class SquareProfile(Profile):
    def __init__(self, low: Impairment, high: Impairment, period: float):
        super().__init__()
        self._low = low
        self._high = high
        self._period = period
        self._is_high = False

    def create_impairment(self) -> Impairment:
        self._is_high = not self._is_high
        if self._is_high:
            return self._high
        return self._low

    def change_period(self) -> float:
        return self._period

    def minimum_rate(self) -> int | None:
        return minimum_rate([self._low.rate, self._high.rate])

    def maximum_rate(self) -> int | None:
        return maximum_rate([self._low.rate, self._high.rate])

    def __str__(self):
        return (
            f"square every {self._period:.0f} s "
            f"between ({self._low}) and ({self._high})"
        )


class RandomProfile(Profile):
    def __init__(
        self,
        impairment: Impairment,
        minimum_rate_value: int,
        maximum_rate_value: int,
        interval: float,
        seed: int | None,
    ):
        super().__init__()
        self._impairment = impairment
        self._minimum_rate = minimum_rate_value
        self._maximum_rate = maximum_rate_value
        self._interval = interval
        self._random = random.Random(seed)

    def create_impairment(self) -> Impairment:
        return replace(
            self._impairment,
            rate=self._random.randint(self._minimum_rate, self._maximum_rate),
        )

    def change_period(self) -> float:
        return self._interval

    def minimum_rate(self) -> int | None:
        return self._minimum_rate

    def maximum_rate(self) -> int | None:
        return self._maximum_rate

    def __str__(self):
        return (
            f"random every {self._interval:.0f} s between "
            f"{self._minimum_rate / 1e6:.1f} and {self._maximum_rate / 1e6:.1f} Mbps"
        )


class TrafficShaper:
    def __init__(
        self, config: Config, relays: list[Relay], profiles: dict[str, Profile]
    ):
        shaper = config.shaper()
        self.ip_address = shaper["ip-address"]
        self._ssh_host = f"{shaper['user']}@{self.ip_address}"
        self._interface = shaper["interface"]
        self._addresses = {
            TESTER_SIDE: config.tester_ip_address(),
            DEVICE_SIDE: config.moblin_ip_address(),
        }
        self._relays = relays
        self._profiles = profiles
        self._directory: Path | None = None
        self._control_path: Path | None = None
        self._control_master: subprocess.Popen | None = None
        self._session: subprocess.Popen | None = None
        self._session_output: deque[str] = deque(maxlen=SESSION_OUTPUT_LINES)
        self._script_path = f"/tmp/moblin-shaper-{os.getpid()}.sh"

    def __enter__(self):
        self._directory = Path(tempfile.mkdtemp(prefix="moblin-shaper-"))
        self._control_path = self._directory / "control"
        try:
            self._start_control_master()
            self._check_dependencies()
            self._upload_setup_script()
            self._start_session()
            self._wait_until_ready()
            self.poll()
        except BaseException:
            self.__exit__(None, None, None)
            raise
        LOGGER.info("Shaping the traffic on %s.", self.ip_address)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._session is not None:
            self._session.kill()
            self._session.wait()
            self._session = None
        if self._control_master is not None:
            self._clean_up()
            self._execute_exit()
            self._control_master.kill()
            self._control_master.wait()
            self._control_master = None
        if self._directory is not None:
            shutil.rmtree(self._directory, ignore_errors=True)
            self._directory = None

    def poll(self):
        now = time.monotonic()
        for group, profile in self._profiles.items():
            impairment = profile.poll(now)
            if impairment is not None:
                self._apply(group, impairment)

    def profile(self, group: str) -> Profile | None:
        return self._profiles.get(group)

    def change_period(self) -> float:
        return max(
            (profile.change_period() for profile in self._profiles.values()), default=0
        )

    def description(self) -> str:
        return ", ".join(
            f"{group} {profile}" for group, profile in self._profiles.items()
        )

    def _apply(self, group: str, impairment: Impairment):
        class_id = GROUP_CLASS_IDS[group]
        result = self._execute(
            f"sudo tc qdisc change dev {self._interface} "
            f"parent 1:{class_id} handle {class_id}: netem "
            f"{impairment.netem_arguments()}",
            check=False,
        )
        if result.returncode != 0:
            LOGGER.warning(
                "Failed to shape the %s to %s: %s",
                group,
                impairment,
                result.stderr.strip() or result.returncode,
            )

    def _start_control_master(self):
        self._control_master = subprocess.Popen(
            [
                "ssh",
                "-M",
                "-N",
                "-S",
                str(self._control_path),
                *SSH_OPTIONS,
                self._ssh_host,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        log_output(self._control_master.stdout, LOGGER)
        log_output(self._control_master.stderr, LOGGER)
        end_time = time.monotonic() + CONTROL_MASTER_TIMEOUT
        while time.monotonic() < end_time:
            if self._execute("true", check=False).returncode == 0:
                return
            time.sleep(0.5)
        raise Exception(f"Timeout connecting to the traffic shaper {self._ssh_host}")

    def _check_dependencies(self):
        missing_dependencies = []
        for executable in ["tc", "socat", "ss"]:
            if self._execute(f"command -v {executable}", check=False).returncode != 0:
                missing_dependencies.append(executable)
        if len(missing_dependencies) > 0:
            raise Exception(
                f"Missing dependencies on the traffic shaper {self._ssh_host}: "
                f"{', '.join(missing_dependencies)}"
            )
        if self._execute("sudo --non-interactive tc", check=False).returncode != 0:
            raise Exception(
                f"Passwordless sudo is not available on the traffic shaper "
                f"{self._ssh_host}"
            )

    def _upload_setup_script(self):
        self._execute_with_input(
            f"cat > {self._script_path}", self._create_setup_script()
        )
        LOGGER.debug(
            "Setup script:\n%s", self._execute(f"cat {self._script_path}").stdout
        )

    def _start_session(self):
        self._session = subprocess.Popen(
            [
                "ssh",
                "-tt",
                "-S",
                str(self._control_path),
                *SSH_OPTIONS,
                self._ssh_host,
                f"sudo -n bash {self._script_path}",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        threading.Thread(target=self._read_session_output, daemon=True).start()

    def _read_session_output(self):
        if self._session is None or self._session.stdout is None:
            return
        try:
            for line in self._session.stdout:
                line = line.rstrip()
                self._session_output.append(line)
                LOGGER.debug(line)
        except Exception:
            pass

    def _format_session_output(self) -> str:
        lines = [line for line in self._session_output if len(line) > 0]
        if len(lines) == 0:
            return ""
        return " Last output from the traffic shaper: " + " ".join(lines)

    def _find_problems(self) -> list[str]:
        checks = [
            f"tc qdisc show dev {self._interface} | grep -q htb || "
            f"echo 'no htb qdisc on {self._interface}'"
        ]
        for relay in self._relays:
            checks.append(
                f"ss -lntu | grep -q ':{relay.port} ' || "
                f"echo 'nothing listening on {relay.protocol} port {relay.port}'"
            )
        result = self._execute("; ".join(checks), check=False)
        if result.returncode != 0:
            return [result.stderr.strip() or f"ssh exited with {result.returncode}"]
        return [line for line in result.stdout.splitlines() if len(line.strip()) > 0]

    def _wait_until_ready(self):
        end_time = time.monotonic() + READY_TIMEOUT
        problems = ["no reply from the traffic shaper"]
        while time.monotonic() < end_time:
            if self._session is not None and self._session.poll() is not None:
                raise Exception(
                    "The traffic shaper session ended unexpectedly."
                    f"{self._format_session_output()}"
                )
            problems = self._find_problems()
            if len(problems) == 0:
                return
            time.sleep(0.5)
        raise Exception(
            f"Timeout waiting for the traffic shaper to start: {', '.join(problems)}."
            f"{self._format_session_output()}"
        )

    def _clean_up(self):
        self._execute(f"sudo tc qdisc del dev {self._interface} root", check=False)
        for relay in self._relays:
            pattern = self._create_relay_pattern(relay)
            self._execute(f"sudo pkill -f {pattern}", check=False)
        self._execute(f"rm -f {self._script_path}", check=False)

    def _create_setup_script(self) -> str:
        lines = [
            "set -e",
            "pids=",
            "clean_up() {",
            "    trap - EXIT HUP INT TERM",
            '    for pid in $pids; do kill "$pid" 2>/dev/null || true; done',
            f"    tc qdisc del dev {self._interface} root 2>/dev/null || true",
            "    exit 0",
            "}",
            "trap clean_up EXIT HUP INT TERM",
            f"tc qdisc del dev {self._interface} root 2>/dev/null || true",
            f"tc qdisc add dev {self._interface} root handle 1: htb default {DEFAULT_CLASS_ID}",
            f"tc class add dev {self._interface} parent 1: classid 1:{DEFAULT_CLASS_ID} "
            f"htb rate {ROOT_RATE}",
        ]
        for group in self._profiles:
            class_id = GROUP_CLASS_IDS[group]
            lines.append(
                f"tc class add dev {self._interface} parent 1: classid 1:{class_id} "
                f"htb rate {ROOT_RATE}"
            )
            lines.append(
                f"tc qdisc add dev {self._interface} parent 1:{class_id} handle {class_id}: "
                f"netem limit {DEFAULT_LIMIT}"
            )
        for relay in self._relays:
            if relay.group not in self._profiles:
                continue
            class_id = GROUP_CLASS_IDS[relay.group]
            for port_type in ["sport", "dport"]:
                lines.append(
                    f"tc filter add dev {self._interface} protocol ip parent 1: prio 1 u32 "
                    f"match ip protocol {PROTOCOL_NUMBERS[relay.protocol]} 0xff "
                    f"match ip {port_type} {relay.port} 0xffff flowid 1:{class_id}"
                )
        for relay in self._relays:
            lines.append(f"{self._create_relay_command(relay)} &")
            lines.append('pids="$pids $!"')
        lines.append("while true; do sleep 1; done")
        return "\n".join(lines) + "\n"

    def _create_relay_command(self, relay: Relay) -> str:
        target = self._addresses[relay.side]
        if relay.protocol == UDP:
            return (
                f"socat -T {RELAY_TIMEOUT} "
                f"UDP-LISTEN:{relay.port},fork,reuseaddr "
                f"UDP:{target}:{relay.port}"
            )
        else:
            return (
                f"socat TCP-LISTEN:{relay.port},fork,reuseaddr "
                f"TCP:{target}:{relay.port}"
            )

    def _create_relay_pattern(self, relay: Relay) -> str:
        if relay.protocol == UDP:
            return f"UDP-LISTEN:{relay.port},"
        else:
            return f"TCP-LISTEN:{relay.port},"

    def _execute(self, command: str, check: bool = True) -> subprocess.CompletedProcess:
        return subprocess.run(
            self._build_execute_arguments(command),
            timeout=EXECUTE_TIMEOUT,
            capture_output=True,
            check=check,
            stdin=subprocess.DEVNULL,
            text=True,
        )

    def _execute_with_input(
        self, command: str, input_data: str
    ) -> subprocess.CompletedProcess:
        return subprocess.run(
            self._build_execute_arguments(command),
            timeout=EXECUTE_TIMEOUT,
            capture_output=True,
            check=True,
            input=input_data,
            text=True,
        )

    def _execute_exit(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            self._build_execute_base_arguments()
            + [
                "-O",
                "exit",
                self._ssh_host,
            ],
            timeout=EXECUTE_TIMEOUT,
            capture_output=True,
            check=False,
            text=True,
        )

    def _build_execute_arguments(self, command: str) -> list[str]:
        LOGGER.debug("SSH command: %s", command)
        return self._build_execute_base_arguments() + [
            self._ssh_host,
            command,
        ]

    def _build_execute_base_arguments(
        self,
    ) -> list[str]:
        return [
            "ssh",
            "-S",
            str(self._control_path),
            *SSH_OPTIONS,
        ]


def minimum_rate(rates: list[int | None]) -> int | None:
    values = [rate for rate in rates if rate is not None]
    if len(values) == 0:
        return None
    return min(values)


def maximum_rate(rates: list[int | None]) -> int | None:
    values = [rate for rate in rates if rate is not None]
    if len(values) == 0:
        return None
    return max(values)


def parse_bitrate(value: str) -> int:
    text = value.strip().lower()
    for suffix in sorted(BITRATE_SUFFIXES, key=len, reverse=True):
        if text.endswith(suffix):
            return int(float(text[: -len(suffix)]) * BITRATE_SUFFIXES[suffix])
    return int(float(text))


def parse_profile(name: str, parameters: str | None) -> Profile:
    values = _parse_values(parameters or "")
    impairment = Impairment(
        delay_ms=float(values.pop("delay", 0)),
        jitter_ms=float(values.pop("jitter", 0)),
        loss_percent=float(values.pop("loss", 0)),
        limit=int(values.pop("limit", DEFAULT_LIMIT)),
    )
    if name == CONSTANT_PROFILE:
        profile = _create_constant_profile(impairment, values)
    elif name == SQUARE_PROFILE:
        profile = _create_square_profile(impairment, values)
    elif name == RANDOM_PROFILE:
        profile = _create_random_profile(impairment, values)
    else:
        raise Exception(f"Unsupported traffic shaping profile '{name}'.")
    if len(values) > 0:
        raise Exception(
            f"Unsupported {name} traffic shaping settings: {', '.join(sorted(values))}."
        )
    return profile


def _parse_values(parameters: str) -> dict[str, str]:
    values = {}
    for part in parameters.split(","):
        part = part.strip()
        if len(part) == 0:
            continue
        if "=" not in part:
            raise Exception(f"Missing value in traffic shaping setting '{part}'.")
        key, _, value = part.partition("=")
        values[key.strip()] = value.strip()
    return values


def _create_constant_profile(impairment: Impairment, values: dict[str, str]) -> Profile:
    return ConstantProfile(_with_rate(impairment, values.pop("rate", None)))


def _create_square_profile(impairment: Impairment, values: dict[str, str]) -> Profile:
    return SquareProfile(
        _with_rate(impairment, values.pop("low-rate", None)),
        _with_rate(impairment, values.pop("high-rate", None)),
        float(values.pop("period", DEFAULT_SQUARE_PERIOD)),
    )


def _create_random_profile(impairment: Impairment, values: dict[str, str]) -> Profile:
    minimum_rate_value = values.pop("min-rate", None)
    maximum_rate_value = values.pop("max-rate", None)
    if minimum_rate_value is None or maximum_rate_value is None:
        raise Exception(
            "The random traffic shaping profile requires min-rate and max-rate."
        )
    seed = values.pop("seed", None)
    return RandomProfile(
        impairment,
        parse_bitrate(minimum_rate_value),
        parse_bitrate(maximum_rate_value),
        float(values.pop("interval", DEFAULT_RANDOM_INTERVAL)),
        None if seed is None else int(seed),
    )


def _with_rate(impairment: Impairment, rate: str | None) -> Impairment:
    if rate is None:
        return impairment
    return replace(impairment, rate=parse_bitrate(rate))
