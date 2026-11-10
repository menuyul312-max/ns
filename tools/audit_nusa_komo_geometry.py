"""Inspect the private ORIGINAL Komo Trellis mesh before making repair claims.

  blender -b --factory-startup --python tools/audit_nusa_komo_geometry.py -- \
      --model ../upload/elder_komo_s3.glb --output generated/komo_geometry_baseline.json
"""

import argparse
import json
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Vector


def inspect(model, output):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(model))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(objs) != 1:
        raise ValueError(f"Expected one mesh, found {len(objs)}")
    mesh = objs[0]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    boundary = [e for e in bm.edges if e.is_boundary]
    nonmanifold = [e for e in bm.edges if not e.is_manifold]
    wires = [e for e in bm.edges if e.is_wire]
    visited = set()
    component_sizes = []
    for vertex in bm.verts:
        if vertex in visited:
            continue
        pending = [vertex]
        visited.add(vertex)
        count = 0
        while pending:
            current = pending.pop()
            count += 1
            for e in current.link_edges:
                other = e.other_vert(current)
                if other not in visited:
                    visited.add(other)
                    pending.append(other)
        component_sizes.append(count)
    points = [mesh.matrix_world @ v.co for v in bm.verts]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    head_front_count = sum(1 for p in points if p.z > lo.z+(hi.z-lo.z)*.64
                           and p.y < (lo.y+hi.y)*.5-.1*(hi.y-lo.y))
    stats = {
        "model": model.name, "vertices": len(bm.verts), "faces": len(bm.faces),
        "edges": len(bm.edges), "boundary_edges": len(boundary),
        "nonmanifold_edges": len(nonmanifold), "wire_edges": len(wires),
        "connected_components": len(component_sizes),
        "largest_components_vertices": sorted(component_sizes, reverse=True)[:12],
        "head_front_vertices": head_front_count,
        "bounds_min": tuple(lo), "bounds_max": tuple(hi),
        "uv_layers": [l.name for l in mesh.data.uv_layers],
        "materials": [m.name for m in mesh.data.materials],
    }
    bm.free()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(stats, indent=2)+"\n")
    print("NUSA_KOMO_GEOMETRY", json.dumps(stats))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    inspect(args.model.resolve(), args.output.resolve())
