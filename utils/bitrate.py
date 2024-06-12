#!/usr/bin/env python3

import random
import time
import subprocess


def set_speed(speed):
    print(time.ctime())
    print(f" - {speed} Mbit")
    subprocess.run(f'sudo tc qdisc replace dev eno1 root netem rate {speed}Mbit',
                   shell=True,
                   check=True)

def do_random():
    minimum = 1.0

    while True:
        speed = round(random.random() * 10 + minimum, 1)
        set_speed(speed)
        time.sleep(15)


def do_constant():
    set_speed(4)


def main():
    # do_random()
    # do_square()
    do_constant()


main()
