"""Create a SECOND original skinned animal-biped GLB for reuse tests.

This is a small, intentionally simple test creature inspired by Indonesian
reptile silhouettes; it is NOT the user's Komo source mesh or an ACNH asset.
Generated GLB belongs in the ignored generated/ directory, never git.

  blender -b --factory-startup --python tools/make_nusa_animal_biped_probe.py -- \
    --output generated/nusa_animal_biped_probe.glb
"""

import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def add_body_part(armature, name, joint, center, radii, color, segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=center)
    mesh = bpy.context.object
    # glTF requires globally distinct node names. Mesh nodes must not collide
    # with bone names or Godot may import renamed joints such as Arm.001.
    mesh.name = "Geo_" + name
    mesh.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mesh.data.materials.append(color)
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    # Deliberate RIGID weights per segment. A real character needs blended
    # shoulder/ankle/neck skin weights and higher-quality retopology.
    group = mesh.vertex_groups.new(name=joint)
    group.add(list(range(len(mesh.data.vertices))), 1.0, "REPLACE")
    modifier = mesh.modifiers.new("NusaSkin", "ARMATURE")
    modifier.object = armature
    mesh.parent = armature
    return mesh


def create_armature():
    armature_data = bpy.data.armatures.new("NusaAnimalBipedRig")
    armature = bpy.data.objects.new("NusaAnimalBipedRig", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    # Bone chain heads/tails are in Blender Z-up coordinates.
    joints = [
        ("Hips", "", (0, 0, .54), (0, 0, .68)),
        ("Spine", "Hips", (0, 0, .68), (0, 0, .85)),
        ("Chest", "Spine", (0, 0, .85), (0, 0, .95)),
        ("Neck", "Chest", (0, 0, .95), (0, 0, 1.03)),
        ("Head", "Neck", (0, 0, 1.03), (0, 0, 1.37)),
        ("LeftShoulder", "Chest", (-.18, 0, .87), (-.28, 0, .87)),
        ("LeftUpperArm", "LeftShoulder", (-.28, 0, .87), (-.32, 0, .67)),
        ("LeftLowerArm", "LeftUpperArm", (-.32, 0, .67), (-.33, -.015, .51)),
        ("LeftHand", "LeftLowerArm", (-.33, -.015, .51), (-.33, -.03, .43)),
        ("RightShoulder", "Chest", (.18, 0, .87), (.28, 0, .87)),
        ("RightUpperArm", "RightShoulder", (.28, 0, .87), (.32, 0, .67)),
        ("RightLowerArm", "RightUpperArm", (.32, 0, .67), (.33, -.015, .51)),
        ("RightHand", "RightLowerArm", (.33, -.015, .51), (.33, -.03, .43)),
        ("LeftUpperLeg", "Hips", (-.125, 0, .52), (-.125, 0, .32)),
        ("LeftLowerLeg", "LeftUpperLeg", (-.125, 0, .32), (-.125, -.01, .14)),
        ("LeftFoot", "LeftLowerLeg", (-.125, -.01, .14), (-.125, -.105, .10)),
        ("LeftToes", "LeftFoot", (-.125, -.105, .10), (-.125, -.19, .08)),
        ("RightUpperLeg", "Hips", (.125, 0, .52), (.125, 0, .32)),
        ("RightLowerLeg", "RightUpperLeg", (.125, 0, .32), (.125, -.01, .14)),
        ("RightFoot", "RightLowerLeg", (.125, -.01, .14), (.125, -.105, .10)),
        ("RightToes", "RightFoot", (.125, -.105, .10), (.125, -.19, .08)),
        ("TailBase", "Hips", (0, .13, .58), (0, .42, .53)),
        ("TailTip", "TailBase", (0, .42, .53), (0, .68, .43)),
        ("Ear_L", "Head", (-.225, 0, 1.33), (-.36, 0, 1.41)),
        ("Ear_R", "Head", (.225, 0, 1.33), (.36, 0, 1.41)),
        ("Muzzle", "Head", (0, -.20, 1.11), (0, -.34, 1.09)),
    ]
    for name, _, head, tail in joints:
        bone = armature_data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        bone.use_deform = True
    for name, parent, _, _ in joints:
        if parent:
            armature_data.edit_bones[name].parent = armature_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def build(output):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = create_armature()
    olive = material("Original_Olive_Clay", (0.41, 0.58, 0.44))
    highlight = material("Original_Sage_Scales", (0.59, 0.71, 0.55))
    belly = material("Original_Pale_Belly", (0.84, 0.79, 0.58))
    claws = material("Original_Dark_Foot", (0.32, 0.39, 0.31))
    add_body_part(armature, "Pelvis", "Hips", (0, 0, .53), (.225, .18, .18), olive)
    add_body_part(armature, "Torso", "Spine", (0, 0, .76), (.235, .18, .28), olive)
    add_body_part(armature, "Belly", "Chest", (0, -.143, .77), (.165, .066, .22), belly)
    add_body_part(armature, "UpperChest", "Chest", (0, 0, .89), (.23, .185, .11), highlight)
    add_body_part(armature, "HeadClay", "Head", (0, -.006, 1.17), (.315, .265, .295), olive)
    add_body_part(armature, "Snout", "Muzzle", (0, -.245, 1.075), (.16, .125, .096), belly)
    add_body_part(armature, "EarLeft", "Ear_L", (-.285, 0, 1.37), (.09, .11, .13), highlight)
    add_body_part(armature, "EarRight", "Ear_R", (.285, 0, 1.37), (.09, .11, .13), highlight)
    add_body_part(armature, "TailBaseClay", "TailBase", (0, .30, .53), (.14, .25, .125), olive)
    add_body_part(armature, "TailEndClay", "TailTip", (0, .53, .475), (.075, .20, .07), olive)
    for side, sign in [("Left", -1), ("Right", 1)]:
        x = sign * .30
        add_body_part(armature, side+"Shoulder", side+"Shoulder", (sign*.23, 0, .865), (.105, .105, .105), olive)
        add_body_part(armature, side+"UpperArm", side+"UpperArm", (x, 0, .765), (.09, .09, .17), olive)
        add_body_part(armature, side+"LowerArm", side+"LowerArm", (sign*.325, -.01, .605), (.074, .072, .135), olive)
        add_body_part(armature, side+"Palm", side+"Hand", (sign*.33, -.02, .49), (.098, .086, .085), highlight)
        add_body_part(armature, side+"Thigh", side+"UpperLeg", (sign*.125, 0, .415), (.115, .13, .17), olive)
        add_body_part(armature, side+"Shin", side+"LowerLeg", (sign*.125, -.01, .24), (.092, .10, .14), olive)
        add_body_part(armature, side+"Foot", side+"Foot", (sign*.125, -.09, .105), (.116, .16, .094), claws)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                              export_animations=False, export_materials="EXPORT",
                              export_apply=False)
    print("NUSA_SECOND_RIG", output, "26 joints, rigid skinned parts, no Nintendo assets")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    build(args.output.absolute())
