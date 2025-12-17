#!/usr/bin/env python3

import subprocess
import argparse


def analyze(video):
    pts_time_lines = subprocess.run(
        f'ffprobe {video} -show_frames -hide_banner -loglevel warning -select_streams v:0 | grep pts_time',
        text=True,
        shell=True,
        check=True,
        capture_output=True).stdout.splitlines()

    prev_pts_time = None

    for pts_time_line in pts_time_lines:
        pts_time = float(pts_time_line.split('=')[1])

        if prev_pts_time is not None:
            delta_ms = 1000 * (pts_time - prev_pts_time)
            print(delta_ms)

        prev_pts_time = pts_time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('video', help='The video to analyze.')
    args = parser.parse_args()

    analyze(args.video)


main()
