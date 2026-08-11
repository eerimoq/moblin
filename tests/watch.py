import argparse
import contextlib
import curses
import math
import re
import time
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


class GridPlot(timeseries.Plot):
    def update(self):
        if self._playing and not self._show_help:
            self.update_data()

    def process_user_input(self):
        pass

    def handle_key(self, key):
        self._modified = True

        if self._show_help:
            self.process_user_input_help(key)
        else:
            self.process_user_input_main(key)

    def move(self, nrows, ncols, row, col):
        self._nrows = nrows
        self._ncols = ncols
        self._modified = True
        self._stdscr = curses.newwin(nrows, ncols, row, col)
        self._stdscr.nodelay(True)


RAM_WATCH = ("RAM usage in MB", make_regex("RAM", "MB"), parse_value)
CPU_WATCH = ("CPU usage in %", make_regex("CPU", "%"), parse_value)
VIDEO_DECODE_ERRORS_WATCH = (
    "Total video decode errors",
    make_counts_regex("Video decode errors"),
    parse_counts_value,
)
DUPLICATED_FRAMES_WATCH = (
    "Total duplicated video frames",
    make_counts_regex("Duplicated video frames"),
    parse_counts_value,
)
DROPPED_FRAMES_WATCH = (
    "Total dropped video frames",
    make_counts_regex("Dropped video frames"),
    parse_counts_value,
)

ALL_WATCHES = [
    RAM_WATCH,
    CPU_WATCH,
    VIDEO_DECODE_ERRORS_WATCH,
    DUPLICATED_FRAMES_WATCH,
    DROPPED_FRAMES_WATCH,
]


def make_producer(regex, value_parser, fin):
    timestamps, values = read_history(regex, value_parser, fin)
    value = values[-1] if values else None

    return timestamps, values, LogFileProducer(regex, value_parser, fin, value)


def watch(title, regex, value_parser=parse_value):
    with open(LOG_FILE, "r", encoding="utf-8") as fin:
        timestamps, values, producer = make_producer(regex, value_parser, fin)

        timeseries.run_curses(
            title,
            timestamps,
            values,
            producer,
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


def calculate_grid(nrows, ncols, count):
    columns = 2 if ncols >= 120 else 1
    rows = math.ceil(count / columns)
    cells = []

    for index in range(count):
        row_index, column_index = divmod(index, columns)
        row = nrows * row_index // rows
        col = ncols * column_index // columns
        cells.append(
            (
                nrows * (row_index + 1) // rows - row,
                ncols * (column_index + 1) // columns - col,
                row,
                col,
            )
        )

    return cells


def read_keys(stdscr):
    keys = []

    while True:
        try:
            keys.append(stdscr.getkey())
        except curses.error:
            return keys


def layout_grid(stdscr, plots):
    nrows, ncols = stdscr.getmaxyx()
    cells = calculate_grid(nrows, ncols, len(plots))
    stdscr.erase()

    if any(cell[0] < 8 or cell[1] < 24 for cell in cells):
        stdscr.addstr(0, 0, "Terminal too small.")
        stdscr.refresh()

        return nrows, ncols, False

    stdscr.refresh()

    for plot, cell in zip(plots, cells):
        plot.move(*cell)

    return nrows, ncols, True


def run_grid(stdscr, plots):
    nrows, ncols, fits = layout_grid(stdscr, plots)

    while True:
        if curses.is_term_resized(nrows, ncols):
            nrows, ncols, fits = layout_grid(stdscr, plots)

        keys = read_keys(stdscr)

        if "q" in keys:
            break

        for plot in plots:
            for key in keys:
                plot.handle_key(key)

            if fits:
                plot.tick()

        time.sleep(0.05)


def make_grid_plot(title, regex, value_parser, fin):
    timestamps, values, producer = make_producer(regex, value_parser, fin)

    return GridPlot(
        curses.newwin(1, 1, 0, 0),
        title,
        timestamps,
        values,
        producer,
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


def watch_grid(watches):
    with contextlib.ExitStack() as stack:
        files = [stack.enter_context(open(LOG_FILE, "r", encoding="utf-8")) for _ in watches]

        def grid(stdscr):
            stdscr.keypad(True)
            stdscr.nodelay(True)
            plots = [
                make_grid_plot(title, regex, value_parser, fin)
                for (title, regex, value_parser), fin in zip(watches, files)
            ]
            run_grid(stdscr, plots)

        with contextlib.suppress(KeyboardInterrupt):
            curses.wrapper(grid)


def do_ram(_args):
    watch(*RAM_WATCH)


def do_cpu(_args):
    watch(*CPU_WATCH)


def do_video_decode_errors(_args):
    watch(*VIDEO_DECODE_ERRORS_WATCH)


def do_duplicated_frames(_args):
    watch(*DUPLICATED_FRAMES_WATCH)


def do_dropped_frames(_args):
    watch(*DROPPED_FRAMES_WATCH)


def do_grid(_args):
    watch_grid(ALL_WATCHES)


def main():
    parser = argparse.ArgumentParser(description="Watch the device resource usage and video statistics.")
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

    subparser = subparsers.add_parser(
        "grid",
        description="Watch all graphs at once in a grid.",
    )
    subparser.set_defaults(func=do_grid)

    args = parser.parse_args()
    args.func(args)


main()
