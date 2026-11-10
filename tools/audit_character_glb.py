"""Check a Nusa glTF/GLB for re-usable rig and skinning contracts.

Only standard-library dependencies. No Nintendo assets or proprietary parsers.
The authored character is optional: use this against any artist-owned GLB.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
             5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
ELEMENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError("GLB header truncated")
    magic, version, length = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or length != len(raw):
        raise ValueError("expected complete glTF 2.0 binary")
    offset = 12
    json_chunk = None
    binary = b""
    while offset < length:
        if offset + 8 > length:
            raise ValueError("GLB chunk header truncated")
        size, kind = struct.unpack_from("<I4s", raw, offset)
        offset += 8
        if offset + size > length:
            raise ValueError("GLB chunk exceeds file length")
        chunk = raw[offset:offset + size]
        if kind == b"JSON":
            json_chunk = json.loads(chunk)
        elif kind == b"BIN\0":
            binary = chunk
        offset += size
    if json_chunk is None:
        raise ValueError("missing JSON chunk")
    return json_chunk, binary


def accessor_values(gltf: dict, binary: bytes, index: int):
    acc = gltf["accessors"][index]
    if "sparse" in acc or "bufferView" not in acc:
        raise ValueError(f"accessor {index} requires sparse support")
    view = gltf["bufferViews"][acc["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise ValueError("external buffer not supported by this GLB auditor")
    fmt, width = COMPONENT[acc["componentType"]]
    parts = ELEMENTS[acc["type"]]
    stride = view.get("byteStride", width * parts)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    unpack = struct.Struct("<" + fmt * parts)
    norm = bool(acc.get("normalized", False))
    for i in range(acc["count"]):
        at = start + stride * i
        if at + unpack.size > min(len(binary), view.get("byteOffset", 0) + view["byteLength"]):
            raise ValueError(f"accessor {index} exceeds bufferView")
        row = unpack.unpack_from(binary, at)
        if norm and acc["componentType"] != 5126:
            max_value = (1 << (width * 8 - (1 if fmt.islower() else 0))) - 1
            row = tuple(max(-1.0, x / max_value) for x in row)
        yield row


def validate_skin(indices: list[tuple], weights: list[tuple], bone_count: int) -> dict:
    invalid_joint = 0
    invalid_weight = 0
    unnormalized = 0
    max_influences = 0
    for joints, values in zip(indices, weights):
        max_influences = max(max_influences, sum(v > 0.001 for v in values))
        if any(not math.isfinite(w) or w < -0.0001 or w > 1.0001 for w in values):
            invalid_weight += 1
        if abs(sum(values) - 1.0) > 0.03:
            unnormalized += 1
        if any((j < 0 or j >= bone_count) for j, w in zip(joints, values) if w > 0.001):
            invalid_joint += 1
    return {"invalid_joint_vertices": invalid_joint, "invalid_weight_vertices": invalid_weight,
            "unnormalized_vertices": unnormalized, "max_influences": max_influences}


def mapped_roles(gltf: dict, profile: dict, joint_ids: list[int]) -> dict:
    names = {gltf["nodes"][idx].get("name", ""): idx for idx in joint_ids}
    mapping = {}
    for role, aliases in profile.get("aliases", {}).items():
        for alias in aliases:
            if alias in names:
                mapping[role] = alias
                break
    return mapping


def load_profile(path: Path, visited: frozenset[Path] = frozenset()) -> dict:
    resolved = path.resolve()
    if resolved in visited:
        raise ValueError("cyclic rig profile inheritance")
    data = json.loads(path.read_text())
    parent_name = data.get("extends")
    if not parent_name:
        return data
    if not parent_name.isidentifier():
        raise ValueError("profile inheritance must use a simple local name")
    base = load_profile(path.with_name(parent_name + ".json"), visited | {resolved})
    for key in ("aliases", "sockets"):
        base[key] = {**base.get(key, {}), **data.get(key, {})}
    for key in ("required_roles", "optional_roles", "ancestor_rules"):
        merged = base.get(key, []).copy()
        for item in data.get(key, []):
            if item not in merged:
                merged.append(item)
        base[key] = merged
    base["id"] = data.get("id", base.get("id"))
    base["description"] = data.get("description", base.get("description"))
    return base


def audit(path: Path, profile: dict) -> dict:
    gltf, binary = read_glb(path)
    problems = []
    warnings = []
    skins = gltf.get("skins", [])
    nodes = gltf.get("nodes", [])
    if not skins:
        problems.append("No glTF skin found")
    joint_ids = skins[0].get("joints", []) if skins else []
    parents = {}
    for parent_id, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                problems.append(f"node {child} has multiple parents")
            parents[child] = parent_id
    for idx in joint_ids:
        visited = set()
        cursor = idx
        while cursor in parents:
            if cursor in visited:
                problems.append(f"cycle in bone hierarchy starting at {idx}")
                break
            visited.add(cursor)
            cursor = parents[cursor]
    mapping = mapped_roles(gltf, profile, joint_ids)
    missing = [role for role in profile.get("required_roles", []) if role not in mapping]
    if missing:
        problems.append("Missing required roles: " + ", ".join(missing))
    for ancestor_role, child_role in profile.get("ancestor_rules", []):
        if ancestor_role not in mapping or child_role not in mapping:
            continue
        ancestor_id = next(i for i in joint_ids if nodes[i].get("name") == mapping[ancestor_role])
        child_id = next(i for i in joint_ids if nodes[i].get("name") == mapping[child_role])
        cursor = parents.get(child_id)
        while cursor is not None and cursor != ancestor_id:
            cursor = parents.get(cursor)
        if cursor != ancestor_id:
            problems.append(f"Hierarchy: {ancestor_role} is not above {child_role}")

    primitives = []
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            entry = {"mesh": mesh.get("name", "unnamed"), "morph_targets": len(prim.get("targets", []))}
            entry["vertices"] = gltf["accessors"][attrs["POSITION"]]["count"] if "POSITION" in attrs else 0
            entry["triangles"] = (gltf["accessors"][prim["indices"]]["count"] // 3
                                  if "indices" in prim and prim.get("mode", 4) == 4 else 0)
            if "JOINTS_0" in attrs and "WEIGHTS_0" in attrs:
                joints = list(accessor_values(gltf, binary, attrs["JOINTS_0"]))
                weights = list(accessor_values(gltf, binary, attrs["WEIGHTS_0"]))
                if len(joints) != len(weights) or len(joints) != entry["vertices"]:
                    problems.append("Skin attribute counts do not match vertices")
                entry.update(validate_skin(joints, weights, len(joint_ids)))
                if any(entry[k] for k in ("invalid_joint_vertices", "invalid_weight_vertices", "unnormalized_vertices")):
                    problems.append(f"Invalid skin weights/joints in {entry['mesh']}")
            else:
                warnings.append(f"{entry['mesh']} has no JOINTS_0 / WEIGHTS_0")
            if "NORMAL" not in attrs or "TEXCOORD_0" not in attrs:
                warnings.append(f"{entry['mesh']} lacks normal or UV0")
            primitives.append(entry)

    shape_names = sorted({name for m in gltf.get("meshes", [])
                          for name in m.get("extras", {}).get("targetNames", [])})
    if not shape_names:
        warnings.append("No facial blend-shape names available")
    return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "profile": profile.get("id", "unknown"), "valid": not problems,
            "nodes": len(nodes), "skins": len(skins), "joint_count": len(joint_ids),
            "bones": [nodes[i].get("name", "") for i in joint_ids],
            "roles": mapping, "primitives": primitives,
            "animations": [a.get("name", "") for a in gltf.get("animations", [])],
            "facial_shapes": shape_names, "errors": problems, "warnings": warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path, help="artist-owned .glb model")
    parser.add_argument("--profile", type=Path,
                        default=Path(__file__).resolve().parents[1] / "data/characters/profiles/humanoid.json")
    parser.add_argument("--output", type=Path, help="optional JSON report path")
    args = parser.parse_args()
    profile = load_profile(args.profile)
    report = audit(args.glb, profile)
    serialized = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized + "\n")
    print(serialized)
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
