"""Build a labelled MP4 and GIF from Blender's rendered Godot motion frames.

Example:
  python3 tools/encode_nusa_motion.py \
    --frames-dir /path/to/motion_all_frames \
    --video /path/to/nusa_motion_16_clips.mp4 \
    --gif /path/to/nusa_motion_16_clips.gif
Requires FFmpeg with libx264, drawtext, hqdn3d, and palettegen.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess


def drawtext(text, y, size, enable="", x=18):
    font = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    safe = text.replace("'", "").replace(":", "-")
    result = (f"drawtext=fontfile={font}:text='{safe}':x={x}:y={y}:"
              f"fontcolor=white:fontsize={size}:shadowcolor=black@0.5:shadowx=1:shadowy=2")
    if enable:
        result += f":enable='{enable}'"
    return result


def encode(frames_dir, video, gif, mode="motion"):
    if not shutil.which("ffmpeg"):
        raise RuntimeError("FFmpeg unavailable")
    manifest = json.loads((frames_dir / "manifest.json").read_text(encoding="utf-8"))
    if mode == "face":
        entries = manifest["expressions"]
        if len(entries) != 12 or manifest["total_frames"] < 40:
            raise ValueError("Incomplete 11-preset face render")
        input_pattern = str(frames_dir / "face_%04d.png")
    else:
        entries = manifest["clips"]
        if mode == "motion" and (len(entries) != 16 or manifest["total_frames"] < 180):
            raise ValueError("Incomplete 16-clip render; will not publish a partial showcase")
        if mode in ("second", "originals") and (not entries or manifest["total_frames"] < len(entries) * 3):
            raise ValueError("Empty or incomplete second-character motion review")
        input_pattern = str(frames_dir / "motion_%05d.png")
    filters = ["hqdn3d=3:2.5:4:3"]
    if mode == "originals":
        # Cut empty studio floor below the feet, reserve true title/legend space
        # instead of overpainting the original character faces.
        filters.extend(["crop=iw:270:0:65", "pad=iw:ih+70:0:70:color=0xc4d1ca"])
    filters.extend([
               "drawbox=x=0:y=0:w=iw:h=78:color=black@0.42:t=fill",
               drawtext("NUSA ORIGINALS / SKINNED PROTOTYPES V0.1" if mode == "originals" else
                        "NUSA CHARACTER / FACE PRESETS V1" if mode == "face" else
                        "NUSA RIG PORTABILITY / PROBE V2.1" if mode == "second" else
                        "NUSA CHARACTER / RIG MOTION V1", 8, 17)])
    for idx, entry in enumerate(entries, start=1):
        category = ("EKSPRESI" if mode == "face" else
                    "AKSI" if mode == "second" and entry["name"] in
                    ("shovel", "pickup", "carry", "interact", "watering", "talk", "wave", "clap") else
                    "GERAK DASAR" if entry["category"] == "locomotion" else "AKSI")
        filters.append(drawtext(f"{idx:02d}  {entry['name'].upper()}   /   {category}", 33, 25,
                                f"between(n,{entry['start_frame']},{entry['end_frame']-1})"))
    filters.append("drawbox=x=0:y=ih-35:w=iw:h=35:color=black@0.38:t=fill")
    if mode == "originals":
        for label, xpos in [("BAHARI", 75), ("LINTANG", 301), ("GAJAH", 526),
                            ("GURITA", 744), ("KOMO", 970)]:
            filters.append(drawtext(label, "h-27", 15, x=xpos))
    else:
        filters.append(drawtext("Godot morph presets + Blender CPU rendering" if mode == "face" else
                                "23 to 26 bone retarget - Blender CPU preview" if mode == "second" else
                                "Godot bone poses + Blender CPU rendering", "h-27", 13))
    video.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", str(manifest["fps"]), "-start_number", "0",
                    "-i", input_pattern, "-vf", ",".join(filters),
                    "-r", "24", "-c:v", "libx264", "-preset", "medium", "-crf", "19",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
    print("NUSA_MOTION_VIDEO", video, video.stat().st_size)
    if gif is not None:
        gif.parent.mkdir(parents=True, exist_ok=True)
        output_width = 850 if mode == "originals" else 360
        palette = (f"fps=10,scale={output_width}:-1:flags=lanczos,split[s0][s1];"
                   "[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(video),
                        "-filter_complex", palette, "-loop", "0", str(gif)], check=True)
        print("NUSA_MOTION_GIF", gif, gif.stat().st_size)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--gif", type=Path, required=False)
    parser.add_argument("--mode", choices=["motion", "face", "second", "originals"], default="motion")
    args = parser.parse_args()
    encode(args.frames_dir, args.video, args.gif, args.mode)
