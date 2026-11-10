"""Transfer the Nusa humanoid rig to an aligned, retopologized biped mesh.

Run (Blender 4.x):
    blender -b --factory-startup --python tools/blender_fit_skin.py -- \
      --reference /path/to/approved_base.glb --target /path/to/retopo.glb \
      --output /path/to/new_character.glb

This is *not* anatomical auto-rigging. It rejects grossly mismatched bounds and
expects feet/orientation and joint locations to align. Winged, quadruped and
damaged Trellis meshes need different templates and human review.
"""

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def imported_objects(path):
    previous = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return list(set(bpy.data.objects) - previous)


def single_mesh(objects, label):
    meshes = sorted((o for o in objects if o.type == "MESH"),
                    key=lambda obj: len(obj.data.vertices), reverse=True)
    if not meshes or (len(meshes) > 1 and len(meshes[1].data.vertices) > len(meshes[0].data.vertices) * 0.25):
        raise ValueError(f"{label}: expected one dominant body mesh; found "
                         + str([(o.name, len(o.data.vertices)) for o in meshes]))
    return meshes[0]


def compatible_bounds(reference, target, tolerance):
    bpy.context.view_layer.update()
    a = [max(float(v), 1e-5) for v in reference.dimensions]
    b = [float(v) for v in target.dimensions]
    ratios = [q / p for p, q in zip(a, b)]
    center_gap = (reference.matrix_world.translation - target.matrix_world.translation).length
    limit = max(a) * (tolerance - 1.0)
    if any(x < 1.0 / tolerance or x > tolerance for x in ratios) or center_gap > limit:
        raise ValueError(f"rest-pose bounds misaligned: ratios={ratios}, center_gap={center_gap:.4f}")
    return ratios, center_gap


def transfer(reference, target, armature):
    original_world = target.matrix_world.copy()
    target.parent = None
    target.matrix_world = original_world
    for item in list(target.modifiers):
        if item.type == "ARMATURE":
            target.modifiers.remove(item)
    for group in list(target.vertex_groups):
        target.vertex_groups.remove(group)
    for group in reference.vertex_groups:
        target.vertex_groups.new(name=group.name)
    modifier = target.modifiers.new("Nusa_SurfaceWeightTransfer", "DATA_TRANSFER")
    modifier.object = reference
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.layers_vgroup_select_src = "ALL"
    modifier.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=modifier.name)

    # Closest-surface interpolation can combine more groups than glTF's
    # standard JOINTS_0/WEIGHTS_0. Keep four influences and renormalize.
    covered = 0
    worst = 0
    for vertex in target.data.vertices:
        weighted = sorted([(g.group, g.weight) for g in vertex.groups if g.weight > 1e-7],
                          key=lambda entry: entry[1], reverse=True)
        if not weighted:
            continue
        covered += 1
        worst = max(worst, len(weighted))
        keep = weighted[:4]
        total = sum(weight for _, weight in keep)
        for group_idx, _ in weighted:
            target.vertex_groups[group_idx].remove([vertex.index])
        for group_idx, weight in keep:
            target.vertex_groups[group_idx].add([vertex.index], weight / total, "REPLACE")
    coverage = covered / max(len(target.data.vertices), 1)
    if coverage < 0.99:
        raise ValueError(f"only {coverage:.1%} of target vertices received weights")
    target.parent = armature
    target.matrix_parent_inverse = armature.matrix_world.inverted()
    target.matrix_world = original_world
    skin = target.modifiers.new("NusaArmature", "ARMATURE")
    skin.object = armature
    return {"vertex_count": len(target.data.vertices), "weighted_ratio": round(coverage, 6),
            "max_preprune_influences": worst, "max_export_influences": 4}


def run(args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    reference_set = imported_objects(args.reference)
    source = single_mesh(reference_set, "reference")
    rigs = [o for o in reference_set if o.type == "ARMATURE"]
    if len(rigs) != 1 or not source.vertex_groups:
        raise ValueError("reference GLB must contain one armature and a skinned body")
    armature = rigs[0]
    target_set = imported_objects(args.target)
    target = single_mesh(target_set, "target")
    ratios, center_gap = compatible_bounds(source, target, args.bounds_tolerance)
    result = transfer(source, target, armature)
    # Preserve only original reference skeleton and the new target mesh.
    for obj in target_set:
        if obj != target:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(source, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = armature
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                               export_skins=True, export_animations=False, export_morph=True)
    report = {"result": "weighted_template_transfer", "output": output.name,
              "bounds_ratios": [round(v, 5) for v in ratios], "center_gap": round(center_gap, 5),
              "bones": len(armature.data.bones), **result,
              "note": "Pose/deformation quality still requires animation and mesh-intersection review"}
    print("NUSA_SKIN_REPORT " + json.dumps(report, sort_keys=True))
    return report


if __name__ == "__main__":
    if "--" not in sys.argv:
        raise SystemExit("Pass -- followed by --reference, --target and --output")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bounds-tolerance", type=float, default=1.25)
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    run(arguments)
