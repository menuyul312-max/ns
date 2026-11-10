"""Render every Nusa Face Controller preset from the original skinned GLB.

Example:
  blender -b --factory-startup --python tools/render_nusa_expressions.py -- \
    --model /path/to/user_model.glb \
    --expressions data/characters/expressions.json \
    --output-dir /path/to/face_frames
"""

import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_nusa_preview import point_camera, prepare_scene


def render(model, expressions_path, output_dir, resolution, samples):
    presets = json.loads(expressions_path.read_text(encoding="utf-8"))
    camera, center, height = prepare_scene(model)
    geometry = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
                and obj.data.shape_keys is not None]
    if not geometry:
        raise ValueError("GLB is missing shape keys")
    keys = {block.name: block for obj in geometry for block in obj.data.shape_keys.key_blocks}
    camera.data.ortho_scale = height * 0.66
    focus = center + Vector((0, 0, height * 0.26))
    point_camera(camera, focus + Vector((-0.6, -2.8, 0.27)), focus)

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    output_dir.mkdir(parents=True, exist_ok=True)

    names = list(presets)
    # Tour each preset, then fade back to neutral for a seamless GIF loop.
    names.append("neutral")
    previous = {}
    manifest = {"fps": 8, "expressions": [], "source": "Godot NusaFaceController preset JSON"}
    frame_id = 0
    for name in names:
        target = presets[name]
        start = frame_id
        for step in range(4):
            blend = (step + 1) / 4.0
            for key_name, block in keys.items():
                if key_name == "Basis":
                    continue
                block.value = (1-blend) * float(previous.get(key_name, 0.0)) + blend * float(target.get(key_name, 0.0))
            bpy.context.view_layer.update()
            scene.render.filepath = str(output_dir / f"face_{frame_id:04d}.png")
            bpy.ops.render.render(write_still=True)
            frame_id += 1
        manifest["expressions"].append({"name": name, "start_frame": start, "end_frame": frame_id})
        print("NUSA_EXPRESSION_RENDER", name)
        previous = target
    manifest["total_frames"] = frame_id
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("NUSA_EXPRESSION_DONE", frame_id, "frames")


if __name__ == "__main__":
    if "--" not in sys.argv:
        raise SystemExit("Pass -- followed by --model, --expressions, --output-dir")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--expressions", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=480)
    parser.add_argument("--samples", type=int, default=8)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    render(args.model, args.expressions, args.output_dir, args.resolution, args.samples)
