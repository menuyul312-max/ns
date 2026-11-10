"""Render Nusa v2 modular eye/mouth texture channels on a private GLB.

This validates the *original Nusa placeholder atlas*, not an ACNH asset.
Run the Godot test_nusa_face_atlas_v2.gd with NUSA_FACE_ATLAS_DIR set first.

  blender -b --factory-startup --python tools/render_nusa_face_atlas_v2.py -- \
    --model assets/character_nusantara.glb --atlas-dir /tmp/nusa_face_atlas \
    --output-dir /tmp/nusa_faces_v2 --resolution 400 --samples 8

The GLB is imported in Blender Z-up coordinates; the face profile rest point
is authored in Godot's Y-up coordinates. Adjust --front-sign if a new GLB has
the opposite forward axis. This is a Blender *preview* of Godot atlas art.
"""

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_nusa_preview import point_camera, prepare_scene


EXPRESSIONS = {
    "neutral": (0, 0), "blink": (1, 0),
    "blink_left": (2, 0), "blink_right": (3, 0),
    "happy": (4, 1), "sad": (5, 2), "angry": (6, 5),
    "surprised": (7, 3), "talk_a": (0, 3),
    "talk_o": (0, 4), "talk_m": (0, 5),
}


def texture_layer(name, atlas_path, width, height, frames, front):
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.object
    plane.name = name
    plane.rotation_euler.x = math.pi / 2.0 if front < 0 else -math.pi / 2.0
    plane.scale = (width * 0.5, height * 0.5, 1.0)
    material = bpy.data.materials.new("Nusa " + name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    coords = nodes.new("ShaderNodeTexCoord")
    scale = nodes.new("ShaderNodeVectorMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = (1.0 / frames, 1.0, 1.0)
    offset = nodes.new("ShaderNodeVectorMath")
    offset.operation = "ADD"
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(atlas_path), check_existing=True)
    texture.extension = "CLIP"
    emission = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    output = nodes.new("ShaderNodeOutputMaterial")
    links = material.node_tree.links
    links.new(coords.outputs["UV"], scale.inputs[0])
    links.new(scale.outputs[0], offset.inputs[0])
    links.new(offset.outputs[0], texture.inputs["Vector"])
    links.new(texture.outputs["Color"], emission.inputs["Color"])
    links.new(texture.outputs["Alpha"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    plane.data.materials.append(material)
    return plane, offset


def render(model, atlas_dir, output_dir, face_profile, resolution, samples, front_sign):
    config = json.loads(face_profile.read_text(encoding="utf-8"))
    camera, center, height = prepare_scene(model)
    # Suppress old face-test shape keys; eyes and mouth are texture-driven.
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.data.shape_keys:
            obj.data.shape_keys.animation_data_clear()
            for key in obj.data.shape_keys.key_blocks:
                if key.name != "Basis":
                    key.value = 0.0

    point = config["face_origin_rest"]
    # Object GLB coordinate conversion is Y-up (Godot) to Z-up (Blender).
    # The imported GLB faces Blender -Y, hence sign controls its front side.
    z_up = float(point[1])
    front_y = front_sign * abs(float(point[2]))
    eyes_offset = config["eye_offset"]
    mouth_offset = config["mouth_offset"]
    eye_width = 128 * float(config["eye_pixel_size"])
    eye_height = 48 * float(config["eye_pixel_size"])
    mouth_width = 64 * float(config["mouth_pixel_size"])
    mouth_height = 36 * float(config["mouth_pixel_size"])
    eye, eye_uv = texture_layer("EyesTextureLayer", atlas_dir / "nusa_eyes_atlas.png",
                                eye_width, eye_height, 8, front_sign)
    mouth, mouth_uv = texture_layer("MouthTextureLayer", atlas_dir / "nusa_mouth_atlas.png",
                                    mouth_width, mouth_height, 6, front_sign)
    eye.location = (float(point[0]) + float(eyes_offset[0]),
                    front_y + front_sign * abs(float(eyes_offset[2])),
                    z_up + float(eyes_offset[1]))
    mouth.location = (float(point[0]) + float(mouth_offset[0]),
                      front_y + front_sign * abs(float(mouth_offset[2])),
                      z_up + float(mouth_offset[1]))

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
    camera.data.ortho_scale = height * 0.72
    look = center + Vector((0.0, 0.0, height * 0.23))
    point_camera(camera, look + Vector((0.0, -height * 3.0, height * 0.01)), look)
    output_dir.mkdir(parents=True, exist_ok=True)
    for i, (name, (eye_idx, mouth_idx)) in enumerate(EXPRESSIONS.items()):
        eye_uv.inputs[1].default_value = (eye_idx / 8.0, 0.0, 0.0)
        mouth_uv.inputs[1].default_value = (mouth_idx / 6.0, 0.0, 0.0)
        scene.render.filepath = str(output_dir / f"face_v2_{i:02d}_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("NUSA_FACE_V2_RENDER", name, scene.render.filepath)
    (output_dir / "manifest.json").write_text(json.dumps({"expressions": list(EXPRESSIONS),
        "source": "Original GLB + procedural Godot-generated Nusa atlases",
        "render": "Blender CPU preview, not Godot runtime"}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--atlas-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--face-profile", type=Path,
                        default=Path("data/characters/face_profiles/humanoid.json"))
    parser.add_argument("--front-sign", type=int, choices=[-1, 1], default=-1)
    parser.add_argument("--resolution", type=int, default=380)
    parser.add_argument("--samples", type=int, default=8)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    render(args.model, args.atlas_dir, args.output_dir, args.face_profile,
           args.resolution, args.samples, args.front_sign)
