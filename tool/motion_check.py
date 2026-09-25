#!/usr/bin/env python3
"""Measures how evenly a rendered credit roll moves, frame to frame.

A crawl reads as smooth when every frame moves the picture the same
distance. This decodes the video with ffmpeg (greyscale, downscaled for
speed), finds the vertical centre of the lit pixels in each frame, and
reports the step between consecutive frames over the stretches where no
line is entering or leaving the frame.

    python3 tool/motion_check.py render.mp4 [--width 480]

Needs ffmpeg and ffprobe on PATH. No Python packages beyond the standard
library.

Reading the result:
  * mean      — pixels per frame at the measured width; scale it up for the
                real width (×4 for 1920 when measuring at 480).
  * spread    — the largest difference of any step from the mean. Below
                ~0.1 px (at the measured width) is smooth; a judder shows as
                a regular pattern such as 3,3,4,3,4 in the steps list.
"""
import argparse
import json
import subprocess
import sys


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height,r_frame_rate", "-of", "json", path],
        check=True, capture_output=True, text=True).stdout
    s = json.loads(out)["streams"][0]
    return s["width"], s["height"], s["r_frame_rate"]


def frames(path, width, height):
    proc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-i", path, "-vf", f"scale={width}:{height}:flags=area,format=gray",
         "-f", "rawvideo", "-"], stdout=subprocess.PIPE)
    size = width * height
    while True:
        buf = proc.stdout.read(size)
        if len(buf) < size:
            break
        yield buf
    proc.wait()


def centre(buf, width, height, threshold=24):
    """Luminance-weighted row centre, or None if anything lit touches an edge."""
    total = weighted = 0
    for y in range(height):
        row = sum(b for b in buf[y * width:(y + 1) * width] if b > threshold)
        if row and (y < 2 or y >= height - 2):
            return None
        total += row
        weighted += row * y
    return weighted / total if total else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("video")
    ap.add_argument("--width", type=int, default=480)
    args = ap.parse_args()

    w, h, rate = probe(args.video)
    mw = args.width
    mh = round(h * mw / w / 2) * 2
    centres = [centre(f, mw, mh) for f in frames(args.video, mw, mh)]

    steps = []
    for a, b in zip(centres, centres[1:]):
        if a is not None and b is not None and a != b:
            steps.append(a - b)
    moving = [s for s in steps if s > 0]
    if len(moving) < 10:
        sys.exit("Too few frames with whole blocks in view to judge; try a longer roll.")

    mean = sum(moving) / len(moving)
    spread = max(abs(s - mean) for s in moving)
    print(f"{args.video}: {w}×{h} @ {rate} fps, measured at {mw}×{mh}")
    print(f"  moving frames: {len(moving)}")
    print(f"  mean step:     {mean:.3f} px/frame  (≈ {mean * w / mw:.2f} px at full width)")
    print(f"  spread:        {spread:.3f} px  → {'SMOOTH' if spread < 0.1 else 'UNEVEN'}")
    print("  first steps:   " + ", ".join(f"{s:.2f}" for s in moving[:24]))


if __name__ == "__main__":
    main()
