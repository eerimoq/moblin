import argparse
import re
from datetime import datetime
from pathlib import Path

from irwin import timeseries

RE_COUNT = re.compile(r":\s*(\d+)")

LOG_FILE = Path(__file__).parent.resolve() / "logs" / "stability.log"


def make_regex(name, unit):
    return re.compile(rf"^(\d+-\d+-\d+ \d+:\d+:\d+,\d+) .* {name}: (\d+) {unit}")


def make_counts_regex(name):
    return re.compile(rf"^(\d+-\d+-\d+ \d+:\d+:\d+,\d+) .* {name}: (.*)\.$")


def parse_value(text):
    return float(text)


def parse_counts_value(text):
    return float(sum(int(count) for count in RE_COUNT.findall(text)))


def parse_line(regex, value_parser, line):
    match = regex.match(line)

    if match is None:
        return None, None

    timestamp = datetime.strptime(match.group(1), "%Y-%m-%d %H:%M:%S,%f").timestamp()

    return timestamp, value_parser(match.group(2))


def read_history(regex, value_parser, fin):
    timestamps = []
    values = []

    for line in fin.read().splitlines():
        timestamp, value = parse_line(regex, value_parser, line)

        if value is not None:
            timestamps.append(timestamp)
            values.append(value)

    return timestamps, values


class LogFileProducer(timeseries.Producer):
    def __init__(self, regex, value_parser, fin, value):
        super().__init__(10)
        self._regex = regex
        self._value_parser = value_parser
        self._fin = fin
        self._value = value
        self._buffer = ""

    def execute_command(self):
        self._buffer += self._fin.read()
        lines = self._buffer.split("\n")
        self._buffer = lines.pop()

        for line in lines:
            _, value = parse_line(self._regex, self._value_parser, line)

            if value is not None:
                self._value = value

        return self._value


def watch(title, regex, value_parser=parse_value):
    with open(LOG_FILE, "r", encoding="utf-8") as fin:
        timestamps, values = read_history(regex, value_parser, fin)
        value = values[-1] if values else None

        timeseries.run_curses(
            title,
            timestamps,
            values,
            LogFileProducer(regex, value_parser, fin, value),
            "none",
            None,
            None,
            None,
            None,
            1,
            0,
            12 * 3600,
            10,
            3600,
        )


def do_ram(_args):
    watch("RAM usage in MB", make_regex("RAM", "MB"))


def do_cpu(_args):
    watch("CPU usage in %", make_regex("CPU", "%"))


def do_video_decode_errors(_args):
    watch(
        "Total video decode errors",
        make_counts_regex("Video decode errors"),
        parse_counts_value,
    )


def do_duplicated_frames(_args):
    watch(
        "Total duplicated video frames",
        make_counts_regex("Duplicated video frames"),
        parse_counts_value,
    )


def do_dropped_frames(_args):
    watch(
        "Total dropped video frames",
        make_counts_regex("Dropped video frames"),
        parse_counts_value,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Watch the device resource usage and video statistics."
    )
    subparsers = parser.add_subparsers(required=True)

    subparser = subparsers.add_parser("ram", description="Watch the device RAM usage.")
    subparser.set_defaults(func=do_ram)

    subparser = subparsers.add_parser("cpu", description="Watch the device CPU usage.")
    subparser.set_defaults(func=do_cpu)

    subparser = subparsers.add_parser(
        "video-decode-errors",
        description="Watch the total number of video decode errors.",
    )
    subparser.set_defaults(func=do_video_decode_errors)

    subparser = subparsers.add_parser(
        "duplicated-frames",
        description="Watch the total number of duplicated video frames.",
    )
    subparser.set_defaults(func=do_duplicated_frames)

    subparser = subparsers.add_parser(
        "dropped-frames",
        description="Watch the total number of dropped video frames.",
    )
    subparser.set_defaults(func=do_dropped_frames)

    args = parser.parse_args()
    args.func(args)


main()
