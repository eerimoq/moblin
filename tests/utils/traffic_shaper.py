import json
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
from enum import StrEnum
from pathlib import Path

from systest import _log_output as log_output
from systest import wait_until

from .config import Config

LOGGER = logging.getLogger(__name__)


class Group(StrEnum):
    STREAM = "stream"
    INGESTS = "ingests"


class Side(StrEnum):
    TESTER = "tester"
    DEVICE = "device"


class Protocol(StrEnum):
    TCP = "tcp"
    UDP = "udp"


class ProfileName(StrEnum):
    CONSTANT = "constant"
    SQUARE = "square"
    RANDOM = "random"


PROTOCOL_NUMBERS = {Protocol.TCP: 6, Protocol.UDP: 17}
GROUP_TARGET_NAMES = {Group.STREAM: "stream", Group.INGESTS: "ingest"}
DEFAULT_CLASS_ID = 1
FIRST_CLASS_ID = 10
UNLIMITED_RATE = 10_000_000_000
ROOT_RATE = f"{UNLIMITED_RATE}bit"
DEFAULT_LIMIT = 1000
RELAY_TIMEOUT = 600
READY_TIMEOUT = 30
EXECUTE_TIMEOUT = 30
SESSION_OUTPUT_LINES = 20
STATISTICS_SEPARATOR = "--- filters ---"
DEFAULT_CONSTANT_RATE = 4_000_000
DEFAULT_SQUARE_LOW_RATE = 3_000_000
DEFAULT_SQUARE_HIGH_RATE = UNLIMITED_RATE
DEFAULT_SQUARE_PERIOD = 60.0
DEFAULT_RANDOM_MINIMUM_RATE = 1_000_000
DEFAULT_RANDOM_MAXIMUM_RATE = 7_000_000
DEFAULT_RANDOM_INTERVAL = 15.0
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
    name: str
    group: Group
    protocol: Protocol
    port: int
    side: Side


@dataclass
class ShapedStream:
    name: str
    group: Group
    class_id: int
    relays: list[Relay]


@dataclass
class RelayFilter:
    prio: int
    stream: ShapedStream
    relay: Relay
    port_type: str
    destination: Side


@dataclass
class Traffic:
    total_bytes: int = 0
    packets: int = 0


@dataclass
class QueueStatistics:
    total_bytes: int = 0
    packets: int = 0
    dropped: int = 0
    overlimits: int = 0
    backlog_bytes: int = 0
    backlog_packets: int = 0


@dataclass
class StreamStatistics:
    name: str
    queue: QueueStatistics
    sent: dict[Side, Traffic]


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
        if self.rate is None:
            arguments += ["rate", ROOT_RATE]
        else:
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
        return f"square every {self._period:.0f} s between ({self._low}) and ({self._high})"


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
        self,
        config: Config,
        device_ip_address: str,
        relays: list[Relay],
        profiles: dict[Group, Profile],
    ):
        shaper = config.shaper()
        self.ip_address = shaper["ip-address"]
        self._ssh_host = f"{shaper['user']}@{self.ip_address}"
        self._interface = shaper["interface"]
        self._addresses = {
            Side.TESTER: config.tester_ip_address(),
            Side.DEVICE: device_ip_address,
        }
        self._relays = relays
        self._profiles = profiles
        self._streams = create_shaped_streams(relays, profiles)
        self._relay_filters = create_relay_filters(self._streams)
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
        self._check_statistics()
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

    def profile(self, group: Group) -> Profile | None:
        return self._profiles.get(group)

    def change_period(self) -> float:
        return max((profile.change_period() for profile in self._profiles.values()), default=0)

    def description(self) -> str:
        return ", ".join(f"{group} {profile}" for group, profile in self._profiles.items())

    def statistics(self) -> list[StreamStatistics]:
        result = self._execute(
            f"tc -s -j qdisc show dev {self._interface}; echo '{STATISTICS_SEPARATOR}'; "
            f"tc -s -j filter show dev {self._interface} parent 1:"
        )
        qdiscs, _, filters = result.stdout.partition(STATISTICS_SEPARATOR)
        queues = self._parse_queue_statistics(qdiscs)
        sent = self._parse_sent_statistics(filters)
        return [
            StreamStatistics(
                name=stream.name,
                queue=queues.get(stream.class_id, QueueStatistics()),
                sent=sent.get(stream.name, {}),
            )
            for stream in self._streams
        ]

    def _check_statistics(self):
        try:
            statistics = self.statistics()
        except Exception as error:
            LOGGER.warning("Failed to read the traffic shaper statistics. %s", error)
            return
        if all(len(stream.sent) == 0 for stream in statistics):
            LOGGER.warning("No per stream statistics available on the traffic shaper %s.", self._ssh_host)

    def _parse_queue_statistics(self, text: str) -> dict[int, QueueStatistics]:
        class_ids = {f"{stream.class_id}:": stream.class_id for stream in self._streams}
        statistics = {}
        for entry in json.loads(text):
            class_id = class_ids.get(entry.get("handle"))
            if class_id is None:
                continue
            statistics[class_id] = QueueStatistics(
                total_bytes=entry.get("bytes", 0),
                packets=entry.get("packets", 0),
                dropped=entry.get("drops", 0),
                overlimits=entry.get("overlimits", 0),
                backlog_bytes=entry.get("backlog", 0),
                backlog_packets=entry.get("qlen", 0),
            )
        return statistics

    def _parse_sent_statistics(self, text: str) -> dict[str, dict[Side, Traffic]]:
        filters = {}
        for entry in json.loads(text):
            statistics = find_statistics(entry)
            if statistics is None:
                continue
            filters[entry.get("pref")] = statistics
        sent: dict[str, dict[Side, Traffic]] = {}
        for relay_filter in self._relay_filters:
            statistics = filters.get(relay_filter.prio)
            if statistics is None:
                continue
            traffic = sent.setdefault(relay_filter.stream.name, {}).setdefault(
                relay_filter.destination, Traffic()
            )
            traffic.total_bytes += statistics.get("bytes", 0)
            traffic.packets += statistics.get("packets", 0)
        return sent

    def _apply(self, group: Group, impairment: Impairment):
        commands = [
            f"sudo tc qdisc change dev {self._interface} "
            f"parent 1:{stream.class_id} handle {stream.class_id}: netem "
            f"{impairment.netem_arguments()}"
            for stream in self._streams
            if stream.group == group
        ]
        if len(commands) == 0:
            return
        result = self._execute(" && ".join(commands), check=False)
        if result.returncode == 0:
            LOGGER.info("Shaping each %s to %s.", GROUP_TARGET_NAMES[group], impairment)
        else:
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
        wait_until(
            lambda: self._execute("true", check=False).returncode == 0,
            f"a connection to the traffic shaper {self._ssh_host}",
        )

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
            raise Exception(f"Passwordless sudo is not available on the traffic shaper {self._ssh_host}")

    def _upload_setup_script(self):
        self._execute_with_input(f"cat > {self._script_path}", self._create_setup_script())
        LOGGER.debug("Setup script:\n%s", self._execute(f"cat {self._script_path}").stdout)

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
            f"tc qdisc show dev {self._interface} | grep -q htb || echo 'no htb qdisc on {self._interface}'"
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
                    f"The traffic shaper session ended unexpectedly.{self._format_session_output()}"
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
            self._create_class_command(DEFAULT_CLASS_ID),
        ]
        for stream in self._streams:
            lines.append(self._create_class_command(stream.class_id))
            lines.append(
                f"tc qdisc add dev {self._interface} parent 1:{stream.class_id} "
                f"handle {stream.class_id}: netem limit {DEFAULT_LIMIT}"
            )
        lines.append(self._create_add_filter_function())
        for relay_filter in self._relay_filters:
            relay = relay_filter.relay
            lines.append(
                f"add_filter {relay_filter.prio} {PROTOCOL_NUMBERS[relay.protocol]} "
                f"{relay_filter.port_type} {relay.port} {relay_filter.stream.class_id}"
            )
        for relay in self._relays:
            lines.append(f"{self._create_relay_command(relay)} &")
            lines.append('pids="$pids $!"')
        lines.append("while true; do sleep 1; done")
        return "\n".join(lines) + "\n"

    def _create_add_filter_function(self) -> str:
        command = (
            f"tc filter add dev {self._interface} protocol ip parent 1: prio $1 u32 "
            "match ip protocol $2 0xff match ip $3 $4 0xffff flowid 1:$5"
        )
        return "\n".join(["add_filter() {", f"    {command} action pass 2>/dev/null || {command}", "}"])

    def _create_class_command(self, class_id: int) -> str:
        return (
            f"tc class add dev {self._interface} parent 1: classid 1:{class_id} "
            f"htb rate {ROOT_RATE} quantum 200000"
        )

    def _create_relay_command(self, relay: Relay) -> str:
        target = self._addresses[relay.side]
        port = relay.port
        protocol = relay.protocol.upper()
        return f"socat -T {RELAY_TIMEOUT} {protocol}-LISTEN:{port},fork,reuseaddr {protocol}:{target}:{port}"

    def _create_relay_pattern(self, relay: Relay) -> str:
        return f"{relay.protocol.upper()}-LISTEN:{relay.port},"

    def _execute(self, command: str, check: bool = True) -> subprocess.CompletedProcess:
        return subprocess.run(
            self._build_execute_arguments(command),
            timeout=EXECUTE_TIMEOUT,
            capture_output=True,
            check=check,
            stdin=subprocess.DEVNULL,
            text=True,
        )

    def _execute_with_input(self, command: str, input_data: str) -> subprocess.CompletedProcess:
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
            self._build_execute_base_arguments() + ["-O", "exit", self._ssh_host],
            timeout=EXECUTE_TIMEOUT,
            capture_output=True,
            check=False,
            text=True,
        )

    def _build_execute_arguments(self, command: str) -> list[str]:
        LOGGER.debug("SSH command: %s", command)
        return self._build_execute_base_arguments() + [self._ssh_host, command]

    def _build_execute_base_arguments(self) -> list[str]:
        return ["ssh", "-S", str(self._control_path), *SSH_OPTIONS]


def create_shaped_streams(relays: list[Relay], profiles: dict[Group, Profile]) -> list[ShapedStream]:
    streams: dict[str, ShapedStream] = {}
    for relay in relays:
        if relay.group not in profiles:
            continue
        stream = streams.get(relay.name)
        if stream is None:
            stream = ShapedStream(relay.name, relay.group, FIRST_CLASS_ID + len(streams), [])
            streams[relay.name] = stream
        stream.relays.append(relay)
    return list(streams.values())


def create_relay_filters(streams: list[ShapedStream]) -> list[RelayFilter]:
    filters: list[RelayFilter] = []
    for stream in streams:
        for relay in stream.relays:
            prio = len(filters) + 1
            filters.append(RelayFilter(prio, stream, relay, "dport", relay.side))
            filters.append(RelayFilter(prio + 1, stream, relay, "sport", other_side(relay.side)))
    return filters


def other_side(side: Side) -> Side:
    if side == Side.DEVICE:
        return Side.TESTER
    return Side.DEVICE


def find_statistics(value: object) -> dict | None:
    if isinstance(value, dict):
        if "bytes" in value and "packets" in value:
            return value
        values: list = list(value.values())
    elif isinstance(value, list):
        values = value
    else:
        return None
    for item in values:
        statistics = find_statistics(item)
        if statistics is not None:
            return statistics
    return None


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


def parse_rate(value: str) -> int:
    try:
        return int(float(value) * 1e6)
    except ValueError:
        raise Exception(f"'{value}' is not a rate in Mbps.") from None


PROFILES_HELP = f"""
Available profiles and their settings, with defaults within parentheses \
and all rates in Mbps:
  constant:
    rate ({DEFAULT_CONSTANT_RATE / 1e6:g})
  square:
    low-rate ({DEFAULT_SQUARE_LOW_RATE / 1e6:g})
    high-rate (unlimited)
    period in seconds ({DEFAULT_SQUARE_PERIOD:g})
  random:
    min-rate ({DEFAULT_RANDOM_MINIMUM_RATE / 1e6:g})
    max-rate ({DEFAULT_RANDOM_MAXIMUM_RATE / 1e6:g})
    interval in seconds ({DEFAULT_RANDOM_INTERVAL:g})
    seed (random)
  any profile:
    delay in milliseconds (0)
    jitter in milliseconds (0)
    loss in percent (0)
    limit in packets ({DEFAULT_LIMIT})
"""


def parse_profile(value: str) -> Profile:
    profile_name, _, parameters = value.partition(",")
    name = _parse_profile_name(profile_name)
    values = _parse_values(parameters)
    impairment = Impairment(
        delay_ms=float(values.pop("delay", 0)),
        jitter_ms=float(values.pop("jitter", 0)),
        loss_percent=float(values.pop("loss", 0)),
        limit=int(values.pop("limit", DEFAULT_LIMIT)),
    )
    if name == ProfileName.CONSTANT:
        profile = _create_constant_profile(impairment, values)
    elif name == ProfileName.SQUARE:
        profile = _create_square_profile(impairment, values)
    else:
        profile = _create_random_profile(impairment, values)
    if len(values) > 0:
        raise Exception(f"Unsupported {name} traffic shaping settings: {', '.join(sorted(values))}.")
    return profile


def _parse_profile_name(name: str) -> ProfileName:
    try:
        return ProfileName(name.strip().lower())
    except ValueError:
        choices = ", ".join(ProfileName)
        raise Exception(f"'{name.strip()}' is not one of the profiles {choices}.") from None


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
    return ConstantProfile(replace(impairment, rate=_pop_rate(values, "rate", DEFAULT_CONSTANT_RATE)))


def _create_square_profile(impairment: Impairment, values: dict[str, str]) -> Profile:
    return SquareProfile(
        replace(impairment, rate=_pop_rate(values, "low-rate", DEFAULT_SQUARE_LOW_RATE)),
        replace(impairment, rate=_pop_rate(values, "high-rate", DEFAULT_SQUARE_HIGH_RATE)),
        float(values.pop("period", DEFAULT_SQUARE_PERIOD)),
    )


def _create_random_profile(impairment: Impairment, values: dict[str, str]) -> Profile:
    seed = values.pop("seed", None)
    return RandomProfile(
        impairment,
        _pop_rate(values, "min-rate", DEFAULT_RANDOM_MINIMUM_RATE),
        _pop_rate(values, "max-rate", DEFAULT_RANDOM_MAXIMUM_RATE),
        float(values.pop("interval", DEFAULT_RANDOM_INTERVAL)),
        None if seed is None else int(seed),
    )


def _pop_rate(values: dict[str, str], name: str, default: int) -> int:
    value = values.pop(name, None)
    if value is None:
        return default
    return parse_rate(value)
