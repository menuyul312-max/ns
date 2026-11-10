"""QuadriFlow study on the watertight Komo consolidation result.

Quadriflow is followed by nearest-surface UV transfer from the original
Trellis mesh. Outputs remain private until an artist reviews deformation.
"""

import argparse
import json
from pathlib import Path
import sys

import bpy
import bmesh

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repair_nusa_komo_mesh import geometry_stats, discard_isolated_islands


def seal_retopology(obj):
    removed = discard_isolated_islands(obj, 100)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    sealed = 0
    # QuadriFlow can leave a tiny isolated triangular opening after removing
    # a disconnected patch; filling once occasionally reveals a second ring.
    for _ in range(5):
        boundaries = [e for e in bm.edges if e.is_boundary]
        if not boundaries:
            break
        sealed += len(boundaries)
        bmesh.ops.holes_fill(bm, edges=boundaries, sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return removed, sealed


def optimize(blend_file, out_dir, target):
    bpy.ops.wm.open_mainfile(filepath=str(blend_file))
    base = bpy.data.objects["Komo_Repaired_Quad_Surface"]
    source = bpy.data.objects["Komo_Original_Hidden_Reference"]
    previous = geometry_stats(base)
    # Preserve a copy for visual comparison and to ensure correct project state.
    base.hide_render = True
    base.hide_set(True)
    improved = base.copy()
    improved.data = base.data.copy()
    improved.name = "Komo_QuadriFlow_Game_Candidate"
    bpy.context.collection.objects.link(improved)
    improved.hide_set(False)
    improved.hide_render = False
    bpy.ops.object.select_all(action="DESELECT")
    improved.select_set(True)
    bpy.context.view_layer.objects.active = improved
    bpy.ops.object.quadriflow_remesh(target_faces=target, use_preserve_sharp=False,
                                    use_preserve_boundary=False)
    removed, sealed = seal_retopology(improved)
    if len(improved.data.uv_layers) == 0:
        improved.data.uv_layers.new(name="UVMap")
    transfer = improved.modifiers.new("Source_UV", "DATA_TRANSFER")
    transfer.object = source
    transfer.use_loop_data = True
    transfer.data_types_loops = {"UV"}
    transfer.loop_mapping = "POLYINTERP_NEAREST"
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    for poly in improved.data.polygons:
        poly.use_smooth = True
    current = geometry_stats(improved)
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "elder_komo_game_candidate.glb"
    bpy.ops.object.select_all(action="DESELECT")
    improved.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                              use_selection=True, export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(out_dir / "komo_game_candidate.blend"))
    result = {"source": str(blend_file), "target_faces": target,
              "pruned_island_vertices": removed, "sealed_boundary_edges": sealed,
              "before": previous, "after": current, "model": str(output)}
    (out_dir / "quadflow_audit.json").write_text(json.dumps(result, indent=2)+"\n")
    print("NUSA_KOMO_QUADFLOW", json.dumps(result), flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--blend", type=Path, required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--faces", type=int, default=12000)
    args = p.parse_args(sys.argv[sys.argv.index("--")+1:])
    optimize(args.blend.resolve(), args.out_dir.resolve(), args.faces)
