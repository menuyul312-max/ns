"""Visual contact sheet for private, unrigged, user-provided Trellis GLBs.

Run with Blender in background and arguments after ``--``. The source models
are imported for rendering only; nothing is uploaded or committed.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import math

import bpy
from mathutils import Vector


def look_at(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def preview(path: Path, output: Path, resolution: int):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if not meshes:
        raise ValueError(f"No meshes in {path}")
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low + high) * 0.5
    extent = max((high - low))
    print("NUSA_BOUNDS", path.name, tuple(round(x, 3) for x in low),
          tuple(round(x, 3) for x in high))
    floor_mat = bpy.data.materials.new("Studio gray green")
    floor_mat.diffuse_color = (0.63, 0.68, 0.60, 1)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(center.x, center.y, low.z - .015 * extent))
    bpy.context.object.data.materials.append(floor_mat)
    world = bpy.data.worlds.new("Soft gray")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.67, .74, .79, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .7
    bpy.context.scene.world = world
    for name, offset, energy in [
        ("Key", (2, -3, 4), 220), ("Fill", (-3, -1, 2), 130), ("Rim", (1, 3, 3), 160)]:
        data = bpy.data.lights.new(name, "AREA")
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = center + Vector(offset) * extent * 1.2
        data.energy = energy
        data.shape = "DISK"
        data.size = 3 * extent
        look_at(obj, center)
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = extent * 1.55
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    output.mkdir(parents=True, exist_ok=True)
    for label, angle in [("front_minus_y", 0), ("side_plus_x", 90),
                         ("back_plus_y", 180), ("side_minus_x", 270)]:
        rad = math.radians(angle)
        camera.location = center + Vector((math.sin(rad) * extent * 3,
                                           -math.cos(rad) * extent * 3,
                                           extent * .1))
        look_at(camera, center)
        scene.render.filepath = str(output / f"{path.stem}_{label}.png")
        bpy.ops.render.render(write_still=True)
        print("NUSA_PREVIEW", scene.render.filepath)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=400)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for model_path in sorted(args.input_dir.glob("*.glb")):
        preview(model_path.resolve(), args.output_dir.resolve(), args.resolution)
