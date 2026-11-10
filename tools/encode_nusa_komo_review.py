"""Package reviewed Komo PNG sequences as labeled MP4 and expression GIF."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont


def font(size):
    path = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def label_frame(path, clip, index, total, mode):
    frame = Image.open(path).convert("RGB")
    # Keep the actual render untouched except a very subtle reduction in
    # no-denoiser CPU speckle and compact legible metadata.
    frame = frame.filter(ImageFilter.GaussianBlur(.36))
    width, height = frame.size
    layer = Image.new("RGBA", frame.size, (0,0,0,0))
    draw = ImageDraw.Draw(layer)
    margin = int(width*.045)
    draw.rounded_rectangle((margin, margin, width-margin, margin+65), radius=13,
                           fill=(19,30,29,206))
    draw.text((margin+18, margin+10), "KOMO  /  NUSA CHARACTER STUDY",
              font=font(max(12,int(width*.026))), fill=(190,213,206,255))
    draw.text((margin+18, margin+32), clip.replace("_"," ").upper(),
              font=font(max(17,int(width*.037))), fill=(252,255,251,255))
    draw.text((width-margin-65, margin+35), f"{index:02}/{total:02}",
              font=font(max(13,int(width*.024))), fill=(190,213,206,255))
    draw.text((margin, height-margin-20),
              "EARLY RIG & FACE REVIEW  |  NOT FINAL ART",
              font=font(max(11,int(width*.018))), fill=(41,58,55,255))
    return Image.alpha_composite(frame.convert("RGBA"), layer).convert("RGB")


def prepare_frames(input_dir, output_dir, mode):
    output_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(input_dir.glob("*.png"))
    if not files:
        raise FileNotFoundError(f"No render frames: {input_dir}")
    clips = []
    for file in files:
        match = re.match(r"(\d+)_([a-z_]+)_(\d+)\.png$", file.name)
        if not match:
            raise ValueError(f"Unexpected preview filename: {file.name}")
        clip = match.group(2)
        if clip not in clips:
            clips.append(clip)
    for i,file in enumerate(files):
        clip = re.match(r"\d+_([a-z_]+)_\d+\.png$",file.name).group(1)
        result = label_frame(file,clip,clips.index(clip)+1,len(clips),mode)
        result.save(output_dir/f"{i:05d}.png", optimize=True)
    return [output_dir/f"{i:05d}.png" for i in range(len(files))], clips


def encode_mp4(images, output, fps):
    args = ["ffmpeg","-hide_banner","-loglevel","error","-y",
            "-framerate",str(fps),"-i",str(images[0].parent/"%05d.png"),
            "-c:v","libx264","-crf","20","-pix_fmt","yuv420p",
            "-movflags","+faststart","-r",str(fps),str(output)]
    subprocess.run(args,check=True)


def encode_gif(images, output, hold_ms):
    frames = [Image.open(path).convert("RGB") for path in images]
    frames[0].save(output, save_all=True, append_images=frames[1:],
                   duration=hold_ms, optimize=True, loop=0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--mode", choices=["expressions","motions"],required=True)
    parser.add_argument("--fps", type=int, default=12)
    parser.add_argument("--version", default="v4_1")
    args = parser.parse_args()
    frames, labels = prepare_frames(args.input, args.out/"frames_labeled", args.mode)
    file_stem = ("komo_expressions_" if args.mode=="expressions"
                 else "komo_16_animations_") + args.version
    video = args.out/(file_stem+".mp4")
    encode_mp4(frames,video,2 if args.mode=="expressions" else args.fps)
    print("NUSA_KOMO_MP4",video,len(frames),"frames",len(labels),"segments",flush=True)
    if args.mode == "expressions":
        gif = args.out/(file_stem+".gif")
        encode_gif(frames,gif,560)
        print("NUSA_KOMO_GIF",gif,flush=True)


if __name__ == "__main__":
    main()
