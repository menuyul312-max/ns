"""Prototype auto-rig for ORIGINAL artist-owned Nusa Trellis GLBs.

Never commits/imports Nintendo assets. Input GLBs are unskinned single meshes.
Adds shared biped controls or a separate eight-tentacle rig, assigns spatial
weights, and generates original named demonstration clips. This is a QA-ready
first pass; it is not topology-aware production skinning.

  blender -b --factory-startup --python tools/rig_nusa_original_glbs.py -- \
      --input-dir ../upload --output-dir generated/private_originals
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector


CLIPS = ["idle", "walk", "run", "turn", "start_stop", "sit", "wade", "swim",
         "shovel", "pickup", "carry", "interact", "watering", "talk", "wave", "clap"]
OCTO_CLIPS = ["idle", "swim", "wave", "talk", "celebrate", "rest"]


def sign_of(name):
    return -1 if name.startswith("Left") or name == "Ear_L" or name == "Wing_L" else 1


def biped_bones(species):
    # Positions in species-normalized x/y/z coordinates, Z=0 floor, Z=1 crown.
    bones = [
        ("Hips", "", (0, 0, .37), (0, 0, .47)),
        ("Spine", "Hips", (0, 0, .47), (0, 0, .57)),
        ("Chest", "Spine", (0, 0, .57), (0, 0, .65)),
        ("Neck", "Chest", (0, 0, .65), (0, 0, .71)),
        ("Head", "Neck", (0, 0, .71), (0, 0, .91)),
    ]
    for side in ("Left", "Right"):
        s = sign_of(side)
        bones.extend([
            (side+"Shoulder", "Chest", (s*.13, 0, .58), (s*.22, 0, .55)),
            (side+"UpperArm", side+"Shoulder", (s*.22, 0, .55), (s*.32, 0, .53)),
            (side+"LowerArm", side+"UpperArm", (s*.32, 0, .53), (s*.41, 0, .52)),
            (side+"Hand", side+"LowerArm", (s*.41, 0, .52), (s*.49, 0, .50)),
            (side+"UpperLeg", "Hips", (s*.105, 0, .37), (s*.105, 0, .255)),
            (side+"LowerLeg", side+"UpperLeg", (s*.105, 0, .255), (s*.105, 0, .125)),
            (side+"Foot", side+"LowerLeg", (s*.105, 0, .125), (s*.105, -.07, .062)),
            (side+"Toes", side+"Foot", (s*.105, -.07, .062), (s*.105, -.18, .052)),
        ])
    if species == "komo":
        bones.extend([
            ("TailBase", "Hips", (0, .15, .39), (0, .32, .33)),
            ("TailTip", "TailBase", (0, .32, .33), (0, .48, .27)),
            ("Muzzle", "Head", (0, -.18, .75), (0, -.42, .71)),
        ])
    if species == "gajah":
        bones.extend([
            ("Ear_L", "Head", (-.18, .0, .82), (-.42, 0, .79)),
            ("Ear_R", "Head", (.18, .0, .82), (.42, 0, .79)),
            ("TrunkBase", "Head", (0, -.19, .75), (0, -.28, .63)),
            ("TrunkTip", "TrunkBase", (0, -.28, .63), (0, -.32, .48)),
        ])
    if species == "lintang":
        bones.extend([
            ("Ear_L", "Head", (-.19, .02, .83), (-.33, .02, .96)),
            ("Ear_R", "Head", (.19, .02, .83), (.33, .02, .96)),
            ("Wing_L", "Chest", (-.16, .12, .53), (-.47, .18, .47)),
            ("Wing_R", "Chest", (.16, .12, .53), (.47, .18, .47)),
        ])
    return bones


def octopus_bones():
    bones = [
        ("Root", "", (0, 0, .20), (0, 0, .32)),
        ("Head", "Root", (0, 0, .32), (0, 0, .76)),
    ]
    for i in range(8):
        angle = i * math.tau / 8
        cs, sn = math.cos(angle), math.sin(angle)
        name = f"Tentacle{i+1:02d}"
        bones.extend([
            (name+"Base", "Root", (cs*.10, sn*.10, .25), (cs*.34, sn*.34, .17)),
            (name+"Tip", name+"Base", (cs*.34, sn*.34, .17), (cs*.49, sn*.49, .14)),
        ])
    return bones


def normalized(value, low, high):
    return (value - low) / max(high-low, 1e-6)


def smooth_interpolate(a, b, value):
    v = max(0.0, min(1.0, (value-a)/max(b-a, 1e-6)))
    return v*v*(3-2*v)


def mix(a, b, factor):
    return {a: 1-factor, b: factor}


def biped_weights(nx, ny, z, species):
    # Skull and appendages first: avoid bleeding face vertices into shoulder.
    ax = abs(nx)
    if species == "gajah" and z > .68 and ax > .25:
        return {"Ear_L" if nx < 0 else "Ear_R": 1.0}
    if species == "lintang" and z > .75 and ax > .23:
        return {"Ear_L" if nx < 0 else "Ear_R": 1.0}
    if species == "komo" and z < .45 and ny > .24 and ax < .24:
        return mix("TailBase", "TailTip", smooth_interpolate(.29, .48, ny))
    if species == "lintang" and .30 < z < .60 and ax > .20 and ny > .10:
        return {"Wing_L" if nx < 0 else "Wing_R": 1.0}
    if species == "gajah" and ny < -.21 and ax < .12 and .45 < z < .8:
        return mix("TrunkBase", "TrunkTip", 1-smooth_interpolate(.50, .72, z))
    if species == "komo" and ny < -.24 and ax < .16 and z > .63:
        return {"Muzzle": 1.0}
    if z > .63:
        return mix("Neck", "Head", smooth_interpolate(.63, .75, z))
    # Place every arm segment on the same model's independent bone chain.
    # Strict x/z gating keeps hands from borrowing weights from the torso.
    if ax > .18 and z > .36:
        side = "Left" if nx < 0 else "Right"
        if ax < .25:
            return mix(side+"Shoulder", side+"UpperArm", smooth_interpolate(.18, .25, ax))
        if ax < .35:
            return mix(side+"UpperArm", side+"LowerArm", smooth_interpolate(.28, .35, ax))
        return mix(side+"LowerArm", side+"Hand", smooth_interpolate(.36, .44, ax))
    if z < .365 and ax > .055:
        side = "Left" if nx < 0 else "Right"
        if z >= .22:
            return mix(side+"LowerLeg", side+"UpperLeg", smooth_interpolate(.22, .29, z))
        if z >= .12:
            return mix(side+"Foot", side+"LowerLeg", smooth_interpolate(.12, .19, z))
        return mix(side+"Toes", side+"Foot", smooth_interpolate(.035, .12, z))
    if z < .45:
        return mix("Hips", "Spine", smooth_interpolate(.39, .49, z))
    return mix("Spine", "Chest", smooth_interpolate(.50, .60, z))


def octopus_weights(nx, ny, z):
    if z >= .34:
        return mix("Root", "Head", smooth_interpolate(.34, .47, z))
    distance = math.hypot(nx, ny)
    if distance < .16:
        return {"Root": 1.0}
    angle = (math.atan2(ny, nx) + math.tau) % math.tau
    i = int(round(angle / (math.tau / 8))) % 8
    name = f"Tentacle{i+1:02d}"
    return mix(name+"Base", name+"Tip", smooth_interpolate(.20, .44, distance))


def build_rig(mesh, species):
    bounds = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
    lo = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    mid = (lo + hi) / 2
    dims = hi - lo
    bones = octopus_bones() if species == "gurita" else biped_bones(species)
    arm_data = bpy.data.armatures.new("Nusa_"+species+"_Armature")
    rig = bpy.data.objects.new("Nusa_"+species+"_Rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def model_position(n):
        return (mid.x+n[0]*dims.x, mid.y+n[1]*dims.y, lo.z+n[2]*dims.z)

    for name, parent, h, t in bones:
        eb = arm_data.edit_bones.new(name)
        eb.head = model_position(h)
        eb.tail = model_position(t)
        eb.use_deform = True
    for name, parent, _, _ in bones:
        if parent:
            arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    # Spatial weights are intentionally identifiable in reports, not claimed
    # as anatomically precise auto-retopology or geodesic heat weights.
    groups = {name: mesh.vertex_groups.new(name=name) for name, _, _, _ in bones}
    influenced = {}
    for vertex in mesh.data.vertices:
        world = mesh.matrix_world @ vertex.co
        nx = (world.x-mid.x)/max(dims.x, 1e-6)
        ny = (world.y-mid.y)/max(dims.y, 1e-6)
        z = normalized(world.z, lo.z, hi.z)
        weights = (octopus_weights(nx, ny, z) if species == "gurita"
                   else biped_weights(nx, ny, z, species))
        total = sum(max(0, v) for v in weights.values())
        if total <= .000001:
            weights = {"Root" if species == "gurita" else "Hips": 1.0}
            total = 1.0
        for name, weight in weights.items():
            if weight > .0001:
                groups[name].add([vertex.index], weight / total, "REPLACE")
                influenced[name] = influenced.get(name, 0) + 1
    modifier = mesh.modifiers.new("Nusa_Skin", "ARMATURE")
    modifier.object = rig
    mesh.parent = rig
    # Preserves imported material and all existing UVs; does not overpaint face.
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    return rig, influenced, dims


def quat_in_bone_local(pose_bone, *world_rotations):
    rotation = Quaternion((1, 0, 0, 0))
    for axis, degree in world_rotations:
        rotation = Quaternion(Vector(axis), math.radians(degree)) @ rotation
    rest = pose_bone.bone.matrix_local.to_quaternion()
    return (rest.inverted() @ rotation @ rest).normalized()


X = (1, 0, 0)
Y = (0, 1, 0)
Z = (0, 0, 1)


def biped_pose(name, t, species):
    p = t * math.tau
    s = math.sin(p)
    c = math.cos(p)
    stride = (38 if name == "run" else 25 if name in ("walk", "wade", "start_stop") else 0)
    swing = 0.0 if name == "idle" else (s*stride)
    rotations = {"Spine": [(X, 2 + c*2)], "Chest": [(X, -1+c*1.5)],
                 "Head": [(X, math.sin(p)*2)]}
    for side in ("Left", "Right"):
        sign = sign_of(side)
        limb_swing = swing * (-1 if side == "Left" else 1)
        leg_swing = -limb_swing
        rotations[side+"UpperArm"] = [(Y, sign*55), (X, limb_swing * .45)]
        rotations[side+"LowerArm"] = [(X, 8 + max(0, limb_swing)*.6)]
        rotations[side+"UpperLeg"] = [(X, leg_swing)]
        rotations[side+"LowerLeg"] = [(X, 5 + max(0, -leg_swing)*.7)]
        rotations[side+"Foot"] = [(X, -leg_swing*.23)]
    if name == "run":
        rotations["Chest"] = [(X, 9)]
    if name == "sit":
        rotations["Hips"] = [(X, -12)]
        for side in ("Left", "Right"):
            rotations[side+"UpperLeg"] = [(X, -65)]
            rotations[side+"LowerLeg"] = [(X, 67)]
    if name == "turn":
        rotations["Hips"] = [(Z, s*15)]
        rotations["Head"] = [(Z, -s*8)]
    if name == "swim":
        rotations["Chest"] = [(X, -20)]
        for side in ("Left", "Right"):
            sign = sign_of(side)
            rotations[side+"UpperArm"] = [(Y, sign*20), (X, sign*s*42)]
            rotations[side+"LowerArm"] = [(X, -25 + c*15)]
            rotations[side+"UpperLeg"] = [(X, sign*s*18)]
    if name in ("wave", "watering"):
        rotations["LeftUpperArm"] = [(Y, 22), (Z, 15)]
        rotations["LeftLowerArm"] = [(Z, 25+s*22)]
    if name in ("clap", "interact"):
        rotations["LeftUpperArm"] = [(Z, 52+c*12), (Y, -5)]
        rotations["RightUpperArm"] = [(Z, -52-c*12), (Y, 5)]
        rotations["LeftLowerArm"] = [(Z, 20)]
        rotations["RightLowerArm"] = [(Z, -20)]
    if name in ("shovel", "pickup"):
        rotations["Spine"] = [(X, 10 + 13*max(0, s))]
        for side in ("Left", "Right"):
            sign = sign_of(side)
            rotations[side+"UpperArm"] = [(Y, sign*38), (X, 15)]
            rotations[side+"LowerArm"] = [(Z, -sign*25)]
    if name in ("carry", "talk"):
        for side in ("Left", "Right"):
            rotations[side+"LowerArm"] = [(X, 25+4*s)]
    if species == "komo":
        rotations["TailBase"] = [(Z, s*11)]
        rotations["TailTip"] = [(Z, -s*13)]
    if species == "gajah":
        rotations["Ear_L"] = [(Z, -s*4)]
        rotations["Ear_R"] = [(Z, s*4)]
        rotations["TrunkBase"] = [(X, s*5)]
        rotations["TrunkTip"] = [(X, -s*8)]
    if species == "lintang":
        rotations["Wing_L"] = [(Y, 8+s*12)]
        rotations["Wing_R"] = [(Y, -8-s*12)]
        rotations["Ear_L"] = [(Z, -s*3)]
        rotations["Ear_R"] = [(Z, s*3)]
    return rotations


def octopus_pose(name, t):
    p = t*math.tau
    s, c = math.sin(p), math.cos(p)
    rotations = {"Head": [(Z, 4*s), (X, 3*c)]}
    for i in range(8):
        stem = f"Tentacle{i+1:02d}"
        offset = p + i*math.tau/8
        strength = (26 if name == "swim" else
                    34 if name in ("wave", "celebrate") else
                    4 if name == "rest" else 12)
        rotations[stem+"Base"] = [(Z, math.sin(offset)*strength),
                                   (X, math.cos(offset)*strength*.45)]
        rotations[stem+"Tip"] = [(Z, -math.sin(offset)*strength*.85)]
    if name == "talk":
        rotations["Head"] = [(X, c*5)]
    return rotations


def add_animations(rig, species):
    rig.animation_data_create()
    clip_names = OCTO_CLIPS if species == "gurita" else CLIPS
    for clip in clip_names:
        action = bpy.data.actions.new(f"nusa_{clip}")
        rig.animation_data.action = action
        for frame in range(1, 49, 4):
            t = (frame-1) / 48
            rotations = (octopus_pose(clip, t) if species == "gurita" else
                         biped_pose(clip, t, species))
            for pose_bone in rig.pose.bones:
                pose_bone.rotation_mode = "QUATERNION"
                angles = rotations.get(pose_bone.name, [])
                pose_bone.rotation_quaternion = quat_in_bone_local(pose_bone, *angles)
                pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=pose_bone.name)
        action.frame_range = (1, 48)
        action.use_fake_user = True
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip, 1, action)
        strip.action_frame_start = 1
        strip.action_frame_end = 48
        strip.mute = False
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True  # NLA export still finds tracks; leave rest pose visible.
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
    return clip_names


def species_from_name(filename):
    for candidate in ("komo", "gajah", "gurita", "bahari", "lintang"):
        if candidate in filename.lower():
            return candidate
    raise ValueError(f"No species profile for {filename}")


def process(input_path, output_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise ValueError(f"Expected one imported mesh, got {len(meshes)}")
    mesh = meshes[0]
    mesh.name = "NusaMesh_" + input_path.stem
    species = species_from_name(input_path.name)
    rig, influences, dims = build_rig(mesh, species)
    clips = add_animations(rig, species)
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / (input_path.stem+"_rigged.glb")
    # NLA_TRACKS maps named actions to independently playable glTF animations.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                              use_selection=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS")
    stats = {"source_file": input_path.name,
             "source_sha256": hashlib.sha256(input_path.read_bytes()).hexdigest(),
             "export_file": output.name, "species": species,
             "vertex_count": len(mesh.data.vertices),
             "polygon_count": len(mesh.data.polygons),
             "bone_count": len(rig.data.bones),
             "bones": sorted(rig.data.bones.keys()),
             "weighted_vertices_per_bone": influences,
             "clip_names": clips,
             "model_dimensions": [round(x, 4) for x in dims],
             "pipeline_stage": "AUTORIG_PROTOTYPE",
             "warnings": ["Spatial heuristic weights require sculpt/skin review",
                          "Original face expression pixels are baked into texture",
                          "Retopology and foot IK are not implemented"]}
    (output_dir / (input_path.stem+"_rig_audit.json")).write_text(
        json.dumps(stats, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    print("NUSA_AUTORIG", species, len(rig.data.bones), len(clips), str(output))
    return stats


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--only", nargs="*", default=[])
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    reports = []
    for source in sorted(args.input_dir.glob("*.glb")):
        if not args.only or source.stem in args.only:
            reports.append(process(source.resolve(), args.output_dir.resolve()))
    if not reports:
        raise SystemExit("No matching models found")
    (args.output_dir / "all_rig_audits.json").write_text(
        json.dumps(reports, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
