"""Mesh-consolidation study for the original Trellis Komo.

Only use with an artist-owned source GLB. Produces a genuinely connected quad
surface by volumetric remeshing; attempts to transfer its source UVs from
the saved original mesh. A production artist must still review UV seams,
limb topology, silhouette, and characteristic facial features.

  blender -b --factory-startup --python tools/repair_nusa_komo_mesh.py -- \
    --model ../upload/elder_komo_s3.glb --output-dir generated/komo_retopo \
    --voxel 0.008
"""

import argparse
import json
from pathlib import Path
import sys

import bmesh
import bpy


def geometry_stats(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonmanifold = sum(1 for e in bm.edges if not e.is_manifold)
    seen = set()
    sizes = []
    for v in bm.verts:
        if v in seen:
            continue
        seen.add(v)
        stack = [v]
        size = 0
        while stack:
            current = stack.pop()
            size += 1
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other not in seen:
                    seen.add(other)
                    stack.append(other)
        sizes.append(size)
    result = {"vertices": len(bm.verts), "faces": len(bm.faces),
              "quads": sum(1 for f in bm.faces if len(f.verts) == 4),
              "boundary_edges": boundary, "nonmanifold_edges": nonmanifold,
              "components": len(sizes), "largest_components": sorted(sizes, reverse=True)[:8]}
    bm.free()
    return result


def discard_isolated_islands(obj, min_verts):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen = set()
    discard = set()
    for start in bm.verts:
        if start in seen:
            continue
        seen.add(start)
        component = [start]
        stack = [start]
        while stack:
            vertex = stack.pop()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other not in seen:
                    seen.add(other)
                    component.append(other)
                    stack.append(other)
        if len(component) < min_verts:
            discard.update(component)
    if discard:
        bmesh.ops.delete(bm, geom=list(discard), context="VERTS")
    removed = len(discard)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return removed


def repair(model, output_dir, voxel, smooth_steps, min_island):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(model))
    originals = [x for x in bpy.context.scene.objects if x.type == "MESH"]
    if len(originals) != 1:
        raise RuntimeError("Expected one real mesh")
    reference = originals[0]
    reference.name = "Komo_Original_Hidden_Reference"
    reference.hide_render = True
    reference.hide_set(True)
    result = reference.copy()
    result.data = reference.data.copy()
    result.name = "Komo_Repaired_Quad_Surface"
    bpy.context.collection.objects.link(result)
    result.hide_set(False)
    result.hide_render = False
    bpy.ops.object.select_all(action="DESELECT")
    result.select_set(True)
    bpy.context.view_layer.objects.active = result
    before = geometry_stats(result)
    result.data.remesh_voxel_size = voxel
    bpy.ops.object.voxel_remesh()
    removed = discard_isolated_islands(result, min_island)
    # Smooth broad voxel terraces while keeping silhouette detail reasonably
    # close; this is NOT quad flow retopo around joints.
    if smooth_steps:
        smoothing = result.modifiers.new("Nusa_Surface_Smooth", "SMOOTH")
        smoothing.factor = .65
        smoothing.iterations = smooth_steps
        bpy.ops.object.modifier_apply(modifier=smoothing.name)
    # DataTransfer UV interpolation needs preexisting target UV layers.
    if len(result.data.uv_layers) == 0:
        result.data.uv_layers.new(name="UVMap")
    transfer = result.modifiers.new("Nusa_Source_UV_Transfer", "DATA_TRANSFER")
    transfer.object = reference
    transfer.use_loop_data = True
    transfer.data_types_loops = {"UV"}
    transfer.loop_mapping = "POLYINTERP_NEAREST"
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    for poly in result.data.polygons:
        poly.use_smooth = True
    after = geometry_stats(result)
    output_dir.mkdir(parents=True, exist_ok=True)
    glb_path = output_dir / "elder_komo_repaired_surface.glb"
    blend_path = output_dir / "komo_repair_study.blend"
    bpy.ops.object.select_all(action="DESELECT")
    result.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB",
                              use_selection=True, export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    audit = {"source": str(model), "voxel_size": voxel, "island_prune_min_verts": min_island,
             "removed_island_vertices": removed,
             "before": before, "after": after, "output": str(glb_path),
             "quality_status": "retopology research; visual and texture-transfer QA needed"}
    (output_dir / "geometry_repair_audit.json").write_text(json.dumps(audit, indent=2)+"\n")
    print("NUSA_KOMO_REPAIR", json.dumps(audit))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--voxel", type=float, default=.008)
    parser.add_argument("--smooth-steps", type=int, default=2)
    parser.add_argument("--min-island", type=int, default=100)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    repair(args.model.resolve(), args.output_dir.resolve(), args.voxel,
           args.smooth_steps, args.min_island)
