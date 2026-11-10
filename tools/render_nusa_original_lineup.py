"""Review 5 user-owned Nusa GLBs with their generated Godot-importable actions.

The output frames are reproducible CPU Blender renders of the actual skinned
GLBs. They are not a claim that facial textures are expression-ready or that
spatial weights have been artist-approved.
"""

import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector


ORDER = ["bahari", "lintang", "gajah", "gurita", "komo"]
CLIPS = ["idle", "walk", "run", "turn", "start_stop", "sit", "wade", "swim",
         "shovel", "pickup", "carry", "interact", "watering", "talk", "wave", "clap"]


def aim(obj, point):
    obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()


def build_scene(source_dir, resolution_x, resolution_y):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rigs = {}
    for idx, species in enumerate(ORDER):
        filepath = next(source_dir.glob(f"*{species}*_rigged.glb"))
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(filepath))
        imported = set(bpy.data.objects)-before
        arm = next(obj for obj in imported if obj.type == "ARMATURE")
        mesh = next(obj for obj in imported if obj.type == "MESH" and
                    obj.name.startswith("NusaMesh_"))
        for helper in imported:
            if helper.type == "MESH" and helper != mesh:
                helper.hide_render = True
        for track in arm.animation_data.nla_tracks:
            track.mute = True
        idle = bpy.data.actions.get("idle_"+arm.name)
        if idle is None:
            raise ValueError("Missing neutral idle for " + species)
        arm.animation_data.action = idle
        bpy.context.scene.frame_set(1)
        # Imported skins often have separate transform helpers. Translate a
        # common parent for ALL imported top-level nodes, never the armature
        # independently of its skin. Static bounds of a skinned mesh can be
        # misleading because bind transforms live in inverse-bind matrices.
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        evaluated_mesh = evaluated.to_mesh()
        min_z = min((evaluated.matrix_world @ v.co).z for v in evaluated_mesh.vertices)
        evaluated.to_mesh_clear()
        placement = bpy.data.objects.new("Placement_"+species, None)
        bpy.context.collection.objects.link(placement)
        for obj in imported:
            if obj.parent not in imported:
                original_transform = obj.matrix_world.copy()
                obj.parent = placement
                obj.matrix_world = original_transform
        tx = (idx-2)*1.34
        tz = -.46-min_z
        placement.location.x = tx
        placement.location.z = tz
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        evaluated_mesh = evaluated.to_mesh()
        world_vertices = [evaluated.matrix_world @ v.co for v in evaluated_mesh.vertices]
        placed_min = min(v.z for v in world_vertices)
        min_y, max_y = min(v.y for v in world_vertices), max(v.y for v in world_vertices)
        evaluated.to_mesh_clear()
        print("NUSA_LINEUP_PLACEMENT", species, round(tz, 4), round(placed_min, 4),
              "Y", round(min_y, 3), round(max_y, 3),
              "parents", arm.parent.name if arm.parent else None,
              mesh.parent.name if mesh.parent else None, flush=True)
        rigs[species] = (arm, mesh)
    ground_material = bpy.data.materials.new("ReviewGround")
    ground_material.diffuse_color = (.72, .78, .70, 1)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.472))
    bpy.context.object.data.materials.append(ground_material)
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.68, .77, .84, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .85
    bpy.context.scene.world = world
    for name, location, power in [
        ("Key", (0, -4, 6), 1000), ("Fill", (-5, -2, 4), 700), ("Rim", (4, 3, 5), 800)]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = 6
        obj = bpy.data.objects.new(name, light)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        aim(obj, Vector((0, 0, 0)))
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 6.9
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera.location = (0, -12, 1.1)
    aim(camera, Vector((0, 0, 0)))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x = resolution_x
    scene.render.resolution_y = resolution_y
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    return rigs


def render(source_dir, output_dir, resolution_x, resolution_y, only):
    rigs = build_scene(source_dir, resolution_x, resolution_y)
    output_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    frame_index = 0
    manifest = {"fps": 8, "source": "private Nusa original GLBs; auto-rig prototype",
                "clips": [], "models": ORDER}
    clips = [c for c in CLIPS if not only or c in only]
    for clip in clips:
        start = frame_index
        for i in range(8):
            for species, (rig, mesh) in rigs.items():
                target = (clip if species != "gurita" else
                          clip if clip in ("idle", "swim", "wave", "talk") else
                          "celebrate" if clip == "clap" else "idle")
                action = bpy.data.actions.get(target+"_"+rig.name)
                if action is None:
                    raise ValueError(f"Missing {target} action for {species}")
                rig.animation_data.action = action
            scene.frame_set(1+6*i)
            scene.render.filepath = str(output_dir / f"motion_{frame_index:05d}.png")
            bpy.ops.render.render(write_still=True)
            frame_index += 1
        manifest["clips"].append({"name": clip, "start_frame": start,
                                  "end_frame": frame_index,
                                  "category": "locomotion" if clip in
                                  ("idle", "walk", "run", "turn", "start_stop", "sit", "wade", "swim")
                                  else "action"})
        print("NUSA_ORIGINAL_LINEUP", clip, frame_index, flush=True)
    manifest["total_frames"] = frame_index
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
    print("NUSA_ORIGINAL_REVIEW_DONE", frame_index, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--resolution-x", type=int, default=1100)
    parser.add_argument("--resolution-y", type=int, default=410)
    parser.add_argument("--only", nargs="*", default=[])
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    render(args.source_dir.resolve(), args.output_dir.resolve(),
           args.resolution_x, args.resolution_y, args.only)
