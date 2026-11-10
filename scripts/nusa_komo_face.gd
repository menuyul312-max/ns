class_name NusaKomoFace
extends Node3D
## Komo-specific textured facial layer, independent from body skin/animation.
## Three independent atlases: left eye, right eye, mouth. The curved base plate
## masks Trellis' baked-in old face; it stays bound to Head via BoneAttachment3D.
## This is ACNH-inspired modular material control, not extracted Nintendo art.

const EYE_CELL := 64
const MOUTH_CELL := 64
const EYE_COUNT := 9
const MOUTH_COUNT := 6
const EYE_STATES := {
	"open": 0, "blink": 1, "happy": 2, "sad": 3, "angry": 4,
	"surprised": 5, "look_left": 6, "look_right": 7, "half": 8,
}
const MOUTH_STATES := {
	"neutral": 0, "smile": 1, "frown": 2, "talk_a": 3,
	"talk_o": 4, "closed": 5,
}
const PRESETS := {
	"neutral": ["open", "open", "neutral"],
	"blink": ["blink", "blink", "neutral"],
	"blink_left": ["blink", "open", "neutral"],
	"blink_right": ["open", "blink", "neutral"],
	"happy": ["happy", "happy", "smile"],
	"sad": ["sad", "sad", "frown"],
	"angry": ["angry", "angry", "closed"],
	"surprised": ["surprised", "surprised", "talk_o"],
	"look_left": ["look_left", "look_left", "neutral"],
	"look_right": ["look_right", "look_right", "neutral"],
	"talk_a": ["open", "open", "talk_a"],
	"talk_o": ["open", "open", "talk_o"],
}

var face_plate: MeshInstance3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var mouth: MeshInstance3D
var left_atlas: AtlasTexture
var right_atlas: AtlasTexture
var mouth_atlas: AtlasTexture
var expression: String = "neutral"


func setup(mask_damaged_legacy_face: bool = true) -> void:
	# A conforming opaque plate replaces gouged underlying Trellis eye/muzzle
	# geometry on both source variants, while fading into the unmodified skull.
	face_plate = _plate(mask_damaged_legacy_face)
	add_child(face_plate)
	left_atlas = _atlas(_make_eyes(-1), EYE_CELL, EYE_COUNT)
	right_atlas = _atlas(_make_eyes(1), EYE_CELL, EYE_COUNT)
	mouth_atlas = _atlas(_make_mouths(), MOUTH_CELL, MOUTH_COUNT)
	left_eye = _decal("EyeLeft", Vector2(-0.154, 0.22), Vector2(0.19, 0.205), left_atlas)
	right_eye = _decal("EyeRight", Vector2(0.154, 0.22), Vector2(0.19, 0.205), right_atlas)
	mouth = _decal("Mouth", Vector2(0, 0.065), Vector2(0.13, 0.105), mouth_atlas)
	add_child(left_eye)
	add_child(right_eye)
	add_child(mouth)
	set_expression("neutral")


func set_expression(name: String) -> bool:
	if not PRESETS.has(name):
		return false
	var selection: Array = PRESETS[name]
	set_eye_state("left", str(selection[0]))
	set_eye_state("right", str(selection[1]))
	set_mouth_state(str(selection[2]))
	expression = name
	return true


func set_eye_state(side: String, state: String) -> bool:
	if not EYE_STATES.has(state):
		return false
	var tex: AtlasTexture = left_atlas if side == "left" else right_atlas if side == "right" else null
	if tex == null:
		return false
	tex.region = Rect2(int(EYE_STATES[state]) * EYE_CELL, 0, EYE_CELL, EYE_CELL)
	return true


func set_mouth_state(state: String) -> bool:
	if not MOUTH_STATES.has(state):
		return false
	mouth_atlas.region = Rect2(int(MOUTH_STATES[state]) * MOUTH_CELL, 0, MOUTH_CELL, MOUTH_CELL)
	return true


static func _front(x: float, y: float) -> float:
	# Convert Blender's -Y head surface to glTF/Godot +Z: measured from
	# Komo's real geometry at eye, muzzle and forehead heights.
	var u: float = x / .285
	return .32 - .31 * maxf(0.0, y - .12) - .057 * u * u


static func _surface(center: Vector2, size: Vector2, subdiv_x: int,
		subdiv_y: int, is_base: bool) -> ArrayMesh:
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var triangles := PackedInt32Array()
	for iy in range(subdiv_y + 1):
		for ix in range(subdiv_x + 1):
			var u: float = float(ix) / subdiv_x
			var v: float = float(iy) / subdiv_y
			var x: float = center.x + (u - .5) * size.x
			var y: float = center.y + (v - .5) * size.y
			points.append(Vector3(x, y, _front(x, y) + (.007 if is_base else .012)))
			uvs.append(Vector2(u, 1.0-v))
			var radius: float = sqrt(pow((x-center.x)/(size.x*.5), 2.0)
				+ pow((y-center.y)/(size.y*.5), 2.0))
			var opacity: float = 1.0 - smoothstep(.78, 1.0, radius)
			colors.append(Color(.238, .263, .250, opacity) if is_base else Color.WHITE)
	for iy in range(subdiv_y):
		for ix in range(subdiv_x):
			var idx: int = iy*(subdiv_x+1)+ix
			var x: float = center.x + (float(ix)+.5)/subdiv_x*size.x - size.x*.5
			var y: float = center.y + (float(iy)+.5)/subdiv_y*size.y - size.y*.5
			var inside: bool = true
			if is_base:
				inside = pow((x-center.x)/(size.x*.5), 2.0) + pow((y-center.y)/(size.y*.5), 2.0) < .93
			if inside:
				triangles.append_array(PackedInt32Array([
					idx, idx+1, idx+subdiv_x+1,
					idx+1, idx+subdiv_x+2, idx+subdiv_x+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _plate(legacy: bool) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = "CurvedCleanFaceBase"
	result.mesh = _surface(Vector2(0, .18), Vector2(.69, .53), 36, 30, true)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(.38, .42, .38) if legacy else Color(.35, .40, .35)
	material.metallic = 0
	material.roughness = 1
	result.material_override = material
	return result


func _decal(label: String, center: Vector2, size: Vector2,
		texture: AtlasTexture) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = _surface(center, size, 10, 8, false)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	result.material_override = material
	return result


static func _atlas(image: Image, cell: int, count: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(0, 0, cell, cell)
	return atlas


static func _make_eyes(side: int) -> Image:
	var canvas := Image.create(EYE_CELL * EYE_COUNT, EYE_CELL, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var ink := Color(.06, .08, .065)
	var shine := Color(.96, .95, .83)
	for state in range(EYE_COUNT):
		var cx: int = state*EYE_CELL + 32
		var cy: int = 32
		var xshift: int = -7 if state == 6 else 7 if state == 7 else 0
		if state in [1, 2]:
			NusaFaceAtlas._draw_curve(canvas, cx, cy, 14, -6.0 if state == 2 else 1.0, ink, 2)
		else:
			var ry: int = 9 if state == 8 else 17 if state == 5 else 13
			NusaFaceAtlas._draw_ellipse(canvas, cx+xshift, cy, 9, ry, ink)
			if state != 4:
				NusaFaceAtlas._draw_ellipse(canvas, cx+xshift-3, cy-5, 3, 4, shine)
		if state in [3, 4]:
			NusaFaceAtlas._draw_curve(canvas, cx, cy-17, 13, -4.0 if state == 4 else 4.0, ink, 2)
	return canvas


static func _make_mouths() -> Image:
	var canvas := Image.create(MOUTH_CELL*MOUTH_COUNT, MOUTH_CELL, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var ink := Color(.085, .07, .065)
	for state in range(MOUTH_COUNT):
		var x: int = state*MOUTH_CELL+32
		match state:
			0: NusaFaceAtlas._draw_curve(canvas, x, 30, 10, 2.0, ink, 2)
			1: NusaFaceAtlas._draw_curve(canvas, x, 28, 15, 9.0, ink, 2)
			2: NusaFaceAtlas._draw_curve(canvas, x, 35, 14, -8.0, ink, 2)
			3: NusaFaceAtlas._draw_ellipse(canvas, x, 33, 11, 15, ink)
			4: NusaFaceAtlas._draw_ellipse(canvas, x, 33, 9, 9, ink)
			5: NusaFaceAtlas._draw_curve(canvas, x, 31, 10, 0.0, ink, 2)
	return canvas
