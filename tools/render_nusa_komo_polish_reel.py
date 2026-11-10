"""Render an honest Komo face/animation review from the real user mesh.

The review uses exactly the same procedural eye/mouth atlas PNGs as Godot.
It does NOT represent Nintendo mesh/animation data or production-final rigging.
Outputs frames used for an MP4/GIF rather than claiming stills are animated.
"""

from pathlib import Path
import argparse
import math
import sys

import bpy
from mathutils import Vector


PRESETS = {
    "neutral": (0, 0, 0), "blink": (1, 1, 0),
    "blink_left": (1, 0, 0), "blink_right": (0, 1, 0),
    "happy": (2, 2, 1), "sad": (3, 3, 2),
    "angry": (4, 4, 5), "surprised": (5, 5, 4),
    "look_left": (6, 6, 0), "look_right": (7, 7, 0),
    "talk_a": (0, 0, 3), "talk_o": (0, 0, 4),
}
MOTIONS = ["idle", "walk", "run", "turn", "start_stop", "sit", "wade",
           "swim", "shovel", "pickup", "carry", "interact", "watering",
           "talk", "wave", "clap"]
EMOTIONS = ["neutral", "neutral", "happy", "look_left", "blink", "happy",
            "surprised", "happy", "angry", "surprised", "neutral", "talk_a",
            "happy", "talk_o", "happy", "happy"]


def front(x, y):
    u = x/.285
    return .32 - .31 * max(0.0, y-.12) - .057*u*u


def make_mesh(name, center, size, columns, rows, ellipse):
    verts = []
    faces = []
    uv_data = []
    alpha_data = []
    for row in range(rows+1):
        for col in range(columns+1):
            u, v = col/columns, row/rows
            x = center[0] + (u-.5)*size[0]
            z = center[1] + (v-.5)*size[1]
            d = front(x, z) + (.007 if ellipse else .012)
            verts.append((x, -d, z))
            uv_data.append((u, 1-v))
            radius = math.sqrt(((x-center[0])/(size[0]/2))**2
                              + ((z-center[1])/(size[1]/2))**2)
            opacity = max(0, min(1, (1-radius)/.22)) if ellipse else 1.0
            alpha_data.append(opacity)
    for row in range(rows):
        for col in range(columns):
            idx = row*(columns+1)+col
            if not ellipse or math.hypot((col+.5-columns/2)/(columns/2),
                                         (row+.5-rows/2)/(rows/2)) < .966:
                faces.append((idx, idx+1, idx+columns+2, idx+columns+1))
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    uv = data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for loop_idx in poly.loop_indices:
            v_idx = data.loops[loop_idx].vertex_index
            uv.data[loop_idx].uv = uv_data[v_idx]
    color = data.color_attributes.new(name="FaceFade", type="FLOAT_COLOR", domain="CORNER")
    for poly in data.polygons:
        for loop_idx in poly.loop_indices:
            a = alpha_data[data.loops[loop_idx].vertex_index]
            color.data[loop_idx].color = (1.0, 1.0, 1.0, a)
    return obj


def bind_to_head(mesh, armature):
    group = mesh.vertex_groups.new(name="Head")
    group.add(list(range(len(mesh.data.vertices))), 1, "REPLACE")
    modifier = mesh.modifiers.new("Head_Deformer", "ARMATURE")
    modifier.object = armature
    mesh.parent = armature


def matte_material():
    mat = bpy.data.materials.new("Komo_Seamless_Face_Shell")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "FaceFade"
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = (.083, .106, .09, 1)
    shader.inputs["Roughness"].default_value = .96
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    output = nodes.new("ShaderNodeOutputMaterial")
    links = mat.node_tree.links
    links.new(attr.outputs["Alpha"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(shader.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    return mat


def atlas_material(name, png):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(png))
    tex.interpolation = "Closest"
    emission = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    output = nodes.new("ShaderNodeOutputMaterial")
    links = mat.node_tree.links
    links.new(tex.outputs["Color"], emission.inputs["Color"])
    links.new(tex.outputs["Alpha"], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    return mat


def set_atlas_frame(mesh, state, count):
    uv = mesh.data.uv_layers.active
    for poly in mesh.data.polygons:
        for loop_index in poly.loop_indices:
            v_id = mesh.data.loops[loop_index].vertex_index
            x, _, z = mesh.data.vertices[v_id].co
            minx = mesh["center_x"]-mesh["size_x"]*.5
            minz = mesh["center_z"]-mesh["size_z"]*.5
            local_u = (x-minx)/mesh["size_x"]
            # Blender's UV origin is bottom-left; Godot's atlases are drawn
            # top-left. This matches Godot's flipped-v decal mesh mapping.
            local_v = (z-minz)/mesh["size_z"]
            uv.data[loop_index].uv = ((state+local_u)/count, local_v)


def face_layers(arm, atlas_dir):
    base = make_mesh("KomoFaceSmoothShell", (0, .18), (.69, .53), 36, 30, True)
    base.data.materials.append(matte_material())
    bind_to_head(base, arm)
    layers = []
    for name, center, size, texture, count in [
        ("left", (-.154, .22), (.19,.205), "eye_left.png", 9),
        ("right", (.154, .22), (.19,.205), "eye_right.png", 9),
        ("mouth", (0, .065), (.13,.105), "mouth.png", 6)]:
        part = make_mesh("KomoFace_"+name, center, size, 10, 8, False)
        part["center_x"], part["center_z"] = center
        part["size_x"], part["size_z"] = size
        part.data.materials.append(atlas_material("KomoAtlas_"+name, atlas_dir/texture))
        bind_to_head(part, arm)
        layers.append((part, count))
    return layers


def light(name, position, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    return obj


def render_setup(size, closeup, samples):
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("Komo_Review_World")
        bpy.context.scene.world = world
    world.color = (.32,.35,.37)
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.39,.49,.52,1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .75
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.454))
    ground = bpy.context.object
    ground.name = "Ground_Backdrop"
    mat = bpy.data.materials.new("Soft_Stone_Background")
    mat.diffuse_color = (.58,.65,.62,1)
    ground.data.materials.append(mat)
    light("WarmKey", (1.5,-2.4,3.0), 480, 3.1, (1,.95,.90))
    light("SoftFill", (-2.2,-1.5,1.4), 230, 2.5, (.79,.88,1))
    light("RearRim", (0,1.6,2.0), 350, 2.5, (.95,.98,1))
    bpy.ops.object.camera_add(location=(1.1,-3.8,.61 if closeup else .16))
    camera = bpy.context.object
    direction = Vector((0,0,.12 if closeup else -.05)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = .86 if closeup else 1.34
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    return scene


def show_expression(layers, name):
    ids = PRESETS[name]
    for (obj, count), state in zip(layers, ids):
        set_atlas_frame(obj, state, count)


def main(model, atlas, out, mode, size, frames_per_clip, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(model))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    face = face_layers(arm, atlas)
    scene = render_setup(size, mode == "expressions", samples)
    out.mkdir(parents=True, exist_ok=True)
    actions = {a.name.lower():a for a in bpy.data.actions}
    print("KOMO_ACTION_NAMES", sorted(actions), flush=True)
    sequence = list(PRESETS) if mode == "expressions" else MOTIONS
    for index, clip in enumerate(sequence):
        expr = clip if mode == "expressions" else EMOTIONS[index]
        count = 1 if mode == "expressions" else frames_per_clip
        action = next((a for name,a in actions.items() if clip.lower() in name), None)
        if mode != "expressions" and action is None:
            raise RuntimeError("Missing animation from user rig: " + clip)
        for step in range(count):
            if mode == "motions":
                arm.animation_data.action = action
                low, high = action.frame_range
                scene.frame_set(int(low + (high-low)*(step/count)))
                if clip in ("talk", "interact") and step%2 == 0:
                    expr = "talk_o" if expr == "talk_a" else "talk_a"
                if clip == "idle" and step == 3:
                    expr = "blink"
            else:
                arm.animation_data.action = None
                scene.frame_set(1)
            show_expression(face, expr)
            scene.render.filepath = str(out / f"{index:02d}_{clip}_{step:02d}.png")
            bpy.ops.render.render(write_still=True)
            print("KOMO_REVIEW_FRAME", index, clip, step, scene.render.filepath, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--atlas", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--mode", choices=["expressions", "motions"], default="expressions")
    parser.add_argument("--size", type=int, default=640)
    parser.add_argument("--frames-per-clip", type=int, default=8)
    parser.add_argument("--samples", type=int, default=12)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    main(args.model.resolve(), args.atlas.resolve(), args.out_dir.resolve(),
         args.mode, args.size, args.frames_per_clip, args.samples)
