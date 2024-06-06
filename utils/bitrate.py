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
        set_speed(args.lowbitrate)
        time.sleep(15)
        set_speed(args.highbitrate)
        time.sleep(15)


def do_random(args):
    minimum = 1.0

    while True:
        speed = round(random.random() * 10 + minimum, 1)
        set_speed(speed)
        time.sleep(15)


def main():
    parser = argparse.ArgumentParser()

    # Workaround to make the subparser required in Python 3.
    subparsers = parser.add_subparsers(title='subcommands',
                                       dest='subcommand')
    subparsers.required = True

    subparser = subparsers.add_parser('constant')
    subparser.add_argument('bitrate', type=float)
    subparser.set_defaults(func=do_constant)

    subparser = subparsers.add_parser('square')
    subparser.add_argument('lowbitrate', type=float)
    subparser.add_argument('highbitrate', type=float)
    subparser.set_defaults(func=do_square)

    subparser = subparsers.add_parser('random')
    subparser.set_defaults(func=do_random)

    args = parser.parse_args()
    args.func(args)


main()
