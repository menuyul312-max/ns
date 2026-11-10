"""Clean the user-supplied Komo's damaged Trellis face/albedo using stylized paint.

Preserves the silhouette and topology of the quad-flow study. Uses per-vertex
color to eliminate baked/smeared facial pixels, making eyes and mouth independent
decal layers. These are original Nusa colors, not Nintendo textures.
"""

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def smoothstep(a, b, x):
    p = max(0.0, min(1.0, (x-a)/(b-a)))
    return p*p*(3-2*p)


def lerp(a, b, t):
    return [a[i]*(1-t)+b[i]*t for i in range(3)]


def restore_face_surface(mesh):
    """Reduce Trellis' concave gouges on the frontal head shell.

    Preserve the species' existing broad head silhouette, cheeks and cranium;
    only the frontal region moves toward a measured soft curved surface.
    """
    inverse = mesh.matrix_world.inverted()
    count = 0
    for vertex in mesh.data.vertices:
        xyz = mesh.matrix_world @ vertex.co
        x, y, z = xyz
        horizontal = 1.0-smoothstep(.235, .355, abs(x))
        vertical = smoothstep(-.052, .048, z)*(1.0-smoothstep(.365, .445, z))
        forward = 1.0-smoothstep(-.085, -.025, y)
        influence = horizontal*vertical*forward*.97
        if influence <= .001:
            continue
        ideal_y = -(.314 - .32*max(0.0, z-.12) - .113*(x/.29)**2)
        revised = Vector((x, y*(1-influence)+ideal_y*influence, z))
        vertex.co = inverse @ revised
        count += 1
    mesh.data.update()
    print("NUSA_KOMO_FACE_RECONSTRUCTION", count, flush=True)


def restore_foot_surface(mesh):
    """Level small Trellis pits at the toe/front-ankle transition."""
    inverse = mesh.matrix_world.inverted()
    changed = 0
    for vertex in mesh.data.vertices:
        p = mesh.matrix_world @ vertex.co
        x, y, z = p
        if z > -.28:
            continue
        region = smoothstep(.04, .09, abs(x)) * (1.0-smoothstep(.255, .325, abs(x)))
        region *= (1.0-smoothstep(-.31, -.275, z))
        region *= (1.0-smoothstep(-.037, .0, y))
        if region < .002:
            continue
        desired = -.16 + .60*(z+.43)
        vertex.co = inverse @ Vector((x, y*(1-region*.82)+desired*region*.82, z))
        changed += 1
    mesh.data.update()
    print("NUSA_KOMO_FOOT_RECONSTRUCTION", changed, flush=True)


def paint(mesh):
    # Blender model front is -Y. The finished glTF/Godot front becomes +Z.
    color = mesh.data.color_attributes.get("KomoSkin")
    if color is None:
        color = mesh.data.color_attributes.new(name="KomoSkin", type="FLOAT_COLOR", domain="CORNER")
    # Vertex colors are linear floats. Precompensate for display gamma so
    # Blender's glTF import matches the original deep moss-green appearance.
    tone = [(.065, .083, .070), (.088, .116, .095)]
    for polygon in mesh.data.polygons:
        for loop_index in polygon.loop_indices:
            xyz = mesh.matrix_world @ mesh.data.vertices[mesh.data.loops[loop_index].vertex_index].co
            x, y, z = xyz
            # Gentle variation adds surface warmth without Trellis' checkerboard noise.
            warmth = max(0.0, min(1.0, .38 + .23*(z+.2)
                + .07*math.sin(32*x+9*z)*math.sin(17*y-11*z)))
            rgb = lerp(*tone, warmth)
            # Broad chest/belly color patch: soft continuous boundary in world-space.
            r = math.sqrt((x/.152)**2 + ((z+.173)/.171)**2)
            forward = 1.0 - smoothstep(-.025, .085, y)
            belly = (1.0-smoothstep(.82, 1.04, r))*forward
            blush = lerp((.42, .15, .145), (.54, .25, .23),
                         smoothstep(-.26, -.03, z))
            rgb = lerp(rgb, blush, belly*.96)
            # A small warm muzzle/chin band, subtle and not a second painted face.
            jaw = (1.0-smoothstep(.11, .18, abs(x))) * (
                smoothstep(-.004, .034, z)*(1.0-smoothstep(.08, .12, z)))
            jaw *= (1.0-smoothstep(-.10, -.02, y))*.45
            rgb = lerp(rgb, (.19, .14, .105), jaw)
            # Tiny, low-amplitude natural shading for stylized skin.
            freckles = .0018 * math.sin(151*x+43*z)*math.sin(113*z-64*y)
            color.data[loop_index].color = (*[max(.0, min(1.0, c+freckles)) for c in rgb], 1.0)

    material = bpy.data.materials.new("Komo_Original_Nusa_SoftSkin")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "KomoSkin"
    material.node_tree.links.new(attribute.outputs["Color"], bsdf.inputs["Base Color"])
    material.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = .94
    bsdf.inputs["Metallic"].default_value = 0
    mesh.data.materials.clear()
    mesh.data.materials.append(material)
    for polygon in mesh.data.polygons:
        polygon.use_smooth = True


def main(source, output):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    mesh = bpy.data.objects["Komo_QuadriFlow_Game_Candidate"]
    restore_face_surface(mesh)
    restore_foot_surface(mesh)
    paint(mesh)
    output.mkdir(parents=True, exist_ok=True)
    glb_file = output / "elder_komo_clean_paint.glb"
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.export_scene.gltf(filepath=str(glb_file), export_format="GLB",
                              use_selection=True, export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "komo_clean_paint.blend"))
    stats = {"source": str(source), "mesh": str(glb_file),
             "colors": "Original vertex paint / baked facial artifacts removed",
             "vertices": len(mesh.data.vertices), "faces": len(mesh.data.polygons),
             "layer": "KomoSkin"}
    (output / "clean_paint_audit.json").write_text(json.dumps(stats, indent=2)+"\n")
    print("NUSA_KOMO_CLEAN_PAINT", json.dumps(stats), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--blend", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    main(args.blend.resolve(), args.out_dir.resolve())
