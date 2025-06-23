#!/usr/bin/env python3

import random
import time
import subprocess
import argparse


def set_speed(speed):
    print(time.ctime())
    print(f" - {speed} Mbit")
    subprocess.run(f'sudo tc qdisc replace dev eno1 root netem rate {speed}Mbit',
                   shell=True,
                   check=True)


def do_constant(args):
    set_speed(args.bitrate)


def do_square(args):
    while True:
        set_speed(args.low_bitrate)
        time.sleep(args.low_time)
        set_speed(args.high_bitrate)
        time.sleep(args.high_time)


def do_random(args):
    minimum = 1.0

    while True:
        speed = round(random.random() * 10 + minimum, 1)
        set_speed(speed)
        time.sleep(15)


def do_reset(args):
    subprocess.run(f'sudo tc qdisc del dev eno1 root', shell=True, check=True)


def main():
    parser = argparse.ArgumentParser()

    # Workaround to make the subparser required in Python 3.
    subparsers = parser.add_subparsers(title='subcommands',
                                       dest='subcommand')
    subparsers.required = True

    subparser = subparsers.add_parser('reset')
    subparser.set_defaults(func=do_reset)

    subparser = subparsers.add_parser('constant')
    subparser.add_argument('bitrate', type=float, help='Bitrate in Mbps.')
    subparser.set_defaults(func=do_constant)

    subparser = subparsers.add_parser('square')
    subparser.add_argument('--low-bitrate',
                           default=2,
                           type=float,
                           help='Low bitrate in Mbps.')
    subparser.add_argument('--high-bitrate',
                           default=10,
                           type=float,
                           help='High bitrate in Mbps.')
    subparser.add_argument('--low-time',
                           default=15,
                           type=float,
                           help='Low bitrate time in seconds.')
    subparser.add_argument('--high-time',
                           default=15,
                           type=float,
                           help='High bitrate time in seconds.')
    subparser.set_defaults(func=do_square)

    subparser = subparsers.add_parser('random')
    subparser.set_defaults(func=do_random)

    args = parser.parse_args()
    args.func(args)


main()
