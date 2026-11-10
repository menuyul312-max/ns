class_name NusaFaceAtlas
extends Node3D
## Stylized independent eye and mouth texture channels. Fallback art is original
## procedural placeholder pixels; productions can replace these atlases.

const EYE_WIDTH: int = 128
const EYE_HEIGHT: int = 48
const MOUTH_WIDTH: int = 64
const MOUTH_HEIGHT: int = 36

const EXPRESSION_FRAMES := {
	"neutral": [0, 0], "blink": [1, 0],
	"blink_left": [2, 0], "blink_right": [3, 0],
	"happy": [4, 1], "sad": [5, 2], "angry": [6, 5],
	"surprised": [7, 3], "talk_a": [0, 3],
	"talk_o": [0, 4], "talk_m": [0, 5]
}

var eye_sprite: Sprite3D
var mouth_sprite: Sprite3D
var eye_atlas: AtlasTexture
var mouth_atlas: AtlasTexture
var current_expression: String = "neutral"


func setup(config: Dictionary) -> void:
	eye_atlas = AtlasTexture.new()
	eye_atlas.atlas = ImageTexture.create_from_image(_make_eye_atlas())
	eye_sprite = Sprite3D.new()
	eye_sprite.name = "EyesTextureLayer"
	eye_sprite.texture = eye_atlas
	eye_sprite.pixel_size = float(config.get("eye_pixel_size", 0.0025))
	eye_sprite.shaded = false
	eye_sprite.double_sided = true
	var eye_offset: Array = config.get("eye_offset", [0.0, 0.073, 0.0])
	eye_sprite.position = Vector3(float(eye_offset[0]), float(eye_offset[1]), float(eye_offset[2]))
	add_child(eye_sprite)
	mouth_atlas = AtlasTexture.new()
	mouth_atlas.atlas = ImageTexture.create_from_image(_make_mouth_atlas())
	mouth_sprite = Sprite3D.new()
	mouth_sprite.name = "MouthTextureLayer"
	mouth_sprite.texture = mouth_atlas
	mouth_sprite.pixel_size = float(config.get("mouth_pixel_size", 0.0022))
	mouth_sprite.shaded = false
	mouth_sprite.double_sided = true
	var mouth_offset: Array = config.get("mouth_offset", [0.0, -0.083, -0.007])
	mouth_sprite.position = Vector3(float(mouth_offset[0]), float(mouth_offset[1]), float(mouth_offset[2]))
	add_child(mouth_sprite)
	set_expression("neutral")


func set_expression(expression: String) -> bool:
	if not EXPRESSION_FRAMES.has(expression):
		return false
	current_expression = expression
	var ids: Array = EXPRESSION_FRAMES[expression]
	eye_atlas.region = Rect2(float(int(ids[0]) * EYE_WIDTH), 0.0, EYE_WIDTH, EYE_HEIGHT)
	mouth_atlas.region = Rect2(float(int(ids[1]) * MOUTH_WIDTH), 0.0, MOUTH_WIDTH, MOUTH_HEIGHT)
	return true


func _make_eye_atlas() -> Image:
	var result: Image = Image.create(EYE_WIDTH * 8, EYE_HEIGHT, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var ink := Color(0.105, 0.115, 0.14, 1.0)
	var light := Color(0.98, 0.96, 0.88, 1.0)
	for variation in range(8):
		for side in range(2):
			var x: int = variation * EYE_WIDTH + (43 if side == 0 else 85)
			var y: int = 25
			var closed: bool = variation == 1 or variation == 2 and side == 0 or variation == 3 and side == 1
			if closed:
				_draw_curve(result, x, y, 12, -3.0, ink, 2)
			elif variation == 4:
				_draw_curve(result, x, y, 10, -6.0, ink, 3)
			else:
				var eye_height: int = 12 if variation == 7 else 9
				_draw_ellipse(result, x, y, 7, eye_height, ink)
				_draw_ellipse(result, x - 2, y - 3, 2, 3, light)
			if variation in [5, 6]:
				var brow_direction: float = -3.0 if variation == 6 else 2.0
				_draw_curve(result, x, y - 14, 9, brow_direction, ink, 2)
	return result


func _make_mouth_atlas() -> Image:
	var result: Image = Image.create(MOUTH_WIDTH * 6, MOUTH_HEIGHT, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var ink := Color(0.16, 0.095, 0.105, 1.0)
	for variation in range(6):
		var x: int = variation * MOUTH_WIDTH + 32
		var y: int = 17
		match variation:
			0: _draw_curve(result, x, y, 6, 1.5, ink, 2)
			1: _draw_curve(result, x, y, 15, 8.0, ink, 2)
			2: _draw_curve(result, x, y + 5, 14, -7.0, ink, 2)
			3: _draw_ellipse(result, x, y + 3, 8, 13, ink)
			4: _draw_ellipse(result, x, y + 3, 8, 8, ink)
			5: _draw_curve(result, x, y, 11, 0.0, ink, 2)
	return result


static func _draw_ellipse(canvas: Image, center_x: int, center_y: int,
		radius_x: int, radius_y: int, color: Color) -> void:
	for y in range(center_y - radius_y, center_y + radius_y + 1):
		for x in range(center_x - radius_x, center_x + radius_x + 1):
			var u: float = float(x - center_x) / float(radius_x)
			var v: float = float(y - center_y) / float(radius_y)
			if u * u + v * v <= 1.0 and x >= 0 and y >= 0 and x < canvas.get_width() and y < canvas.get_height():
				canvas.set_pixel(x, y, color)


static func _draw_curve(canvas: Image, center_x: int, center_y: int,
		half_width: int, bend: float, color: Color, radius: int) -> void:
	for dx in range(-half_width, half_width + 1):
		var p: float = float(dx) / float(half_width)
		var y: int = center_y + roundi(bend * (1.0 - p * p))
		_draw_ellipse(canvas, center_x + dx, y, radius, radius, color)
