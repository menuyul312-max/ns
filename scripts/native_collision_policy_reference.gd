class_name NativeCollisionPolicyReference
extends RefCounted
## A bounded reference for ELF 0xda9a60..0xda9b30 from the user's RE repo.
## Mask-bit meanings and the geometric collision solver remain UNKNOWN.
## Never feed these masks into Godot's collision_layer/collision_mask.


static func resolve(table_mode: int, player_selector: int, player_flags: int, condition_bit0: bool, player_scalar_field_178: int, collider_field_178: int) -> Dictionary:
	var mode: int = table_mode if player_selector == 2 else player_selector
	if (player_flags & 0x40) != 0 and mode != 2:
		mode = 1
	var mask: int = 0
	if mode == 1:
		mask = 0x201
	elif mode == 0 and not condition_bit0:
		mask = 0x80 if player_scalar_field_178 == 0 else 0x201
	var next_field: int = collider_field_178 & ~1
	if (mode == 0 or mode == 1) and not condition_bit0:
		next_field |= 1
	return {"effective_mode": mode, "raw_mask": mask, "collider_field_178": next_field}
