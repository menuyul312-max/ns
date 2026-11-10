"""Render front and three-quarter previews of an approved user-owned GLB.

Usage:
  blender -b --factory-startup --python tools/render_nusa_preview.py -- \
    --model /path/to/model.glb --output-dir /path/to/previews

This uses Blender Cycles in CPU mode. The images are model previews, *not*
Godot runtime captures and not Nintendo characters.
"""

import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def point_camera(camera, position, focus):
    camera.location = position
    camera.rotation_euler = (Vector(focus) - camera.location).to_track_quat("-Z", "Y").to_euler()


def prepare_scene(model):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(model))
    # glTF importer may create unskinned helper shapes for armature controls;
    # frame the actual skinned body, not those invisible construction helpers.
    meshes = [obj for obj in bpy.context.scene.objects
              if obj.type == "MESH" and any(mod.type == "ARMATURE" for mod in obj.modifiers)]
    if not meshes:
        raise ValueError("GLB contains no mesh")
    bbox = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(v[d] for v in bbox) for d in range(3)))
    high = Vector(tuple(max(v[d] for v in bbox) for d in range(3)))
    center = (low + high) * 0.5
    height = high.z - low.z

    mat = bpy.data.materials.new("Warm studio ground")
    mat.diffuse_color = (0.73, 0.78, 0.74, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = 0.86
    bpy.ops.mesh.primitive_plane_add(size=200, location=(center.x, center.y, low.z - height * 0.02))
    floor = bpy.context.object
    floor.name = "StudioFloor"
    floor.data.materials.append(mat)

    world = bpy.data.worlds.new("Light blue studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.72, 0.80, 0.86, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.75
    bpy.context.scene.world = world

    for name, pos, power, size in [
        ("Key", (2.0, -3.0, 4.2), 500, 3.0),
        ("Fill", (-3.0, -1.0, 2.0), 280, 2.4),
        ("Rim", (1.0, 3.0, 3.6), 350, 2.3),
    ]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = size
        obj = bpy.data.objects.new(name, light)
        bpy.context.collection.objects.link(obj)
        obj.location = center + Vector(pos) * height * 0.8
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = height * 1.28
    return camera, center, height


def render(model, output_dir, resolution, samples):
    camera, center, height = prepare_scene(model)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    output_dir.mkdir(parents=True, exist_ok=True)
    target = center + Vector((0, 0, height * 0.01))
    distance = height * 3.0
    for name, angle in [("front", 0.0), ("three_quarter", -38.0)]:
        radians = math.radians(angle)
        eye = center + Vector((math.sin(radians) * distance,
                               -math.cos(radians) * distance, height * 0.22))
        point_camera(camera, eye, target)
        filename = output_dir / f"nusa_character_{name}.png"
        scene.render.filepath = str(filename)
        bpy.ops.render.render(write_still=True)
        print("NUSA_RENDER " + str(filename))


if __name__ == "__main__":
    if "--" not in sys.argv:
        raise SystemExit("Pass -- followed by --model and --output-dir")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=800)
    parser.add_argument("--samples", type=int, default=24)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    render(args.model, args.output_dir, args.resolution, args.samples)
