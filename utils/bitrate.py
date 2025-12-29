#!/usr/bin/env python3

import random
import time
import subprocess
import argparse


def set_bitrate_and_loss(bitrate, loss):
    if bitrate is None and loss is None:
        print('Neither bitrate nor loss given. Aborting...')
        return

    print(time.ctime())
    args = ''

    if bitrate is not None:
        print(f" - Bitrate {bitrate} Mbit")
        args += f' rate {bitrate}Mbit'

    if loss is not None:
        print(f" - Loss {loss} %")
        args += f' loss {loss}%'

    subprocess.run(f'sudo tc qdisc replace dev eno1 root netem' + args,
                   shell=True,
                   check=True)


def do_constant(args):
    set_bitrate_and_loss(args.bitrate, args.loss)


def do_square(args):
    while True:
        set_bitrate_and_loss(args.low_bitrate, args.loss)
        time.sleep(args.low_time)
        set_bitrate_and_loss(args.high_bitrate, args.loss)
        time.sleep(args.high_time)


def do_random(args):
    minimum = 1.0

    while True:
        bitrate = round(random.random() * 10 + minimum, 1)
        set_bitrate_and_loss(bitrate, args.loss)
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
    subparser.add_argument('--bitrate', type=float, help='Bitrate in Mbps.')
    subparser.add_argument('--loss', type=float, help='Loss in %%.')
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
    subparser.add_argument('--loss', type=float, help='Loss in %%.')
    subparser.set_defaults(func=do_square)

    subparser = subparsers.add_parser('random')
    subparser.add_argument('--loss', type=float, help='Loss in %%.')
    subparser.set_defaults(func=do_random)

    args = parser.parse_args()
    args.func(args)


main()
