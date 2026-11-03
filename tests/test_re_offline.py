"""Offline contract smoke tests when the Godot executable is unavailable.

These tests verify the published reference examples and that relevant GDScript
entry points exist. They do NOT execute or validate GDScript/Godot shaders.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def native_index(value: float) -> int:
    return int(int(value) / 5.0) - int(value < 0)


def sector(u: float, v: float) -> int:
    a = v - u
    b = u + v - 5.0
    return (2 if b >= 0 else 1) if a >= 0 else (3 if b >= 0 else 0)


def raw_collision(table, selector, flags, condition, player_field, collider_field):
    mode = table if selector == 2 else selector
    if flags & 0x40 and mode != 2:
        mode = 1
    mask = 0
    if mode == 1:
        mask = 0x201
    elif mode == 0 and not condition:
        mask = 0x80 if player_field == 0 else 0x201
    result_field = (collider_field & ~1) | int(mode in (0, 1) and not condition)
    return mode, mask, result_field


class ReferenceContractSmoke(unittest.TestCase):
    def test_negative_native_edges(self):
        examples = {-10: -3, -5: -2, -4.9: -1, -0.1: -1, 0: 0, 4.9: 0, 5: 1, 10: 2}
        for source, wanted in examples.items():
            with self.subTest(source=source):
                self.assertEqual(native_index(source), wanted)

    def test_diagonal_four_sectors(self):
        cardinal = [(2.5, 1.25), (1.25, 2.5), (2.5, 3.75), (3.75, 2.5)]
        self.assertEqual([sector(*uv) for uv in cardinal], [0, 1, 2, 3])
        self.assertEqual(sector(2.5, 2.5), 2)

    def test_overlay_inheritance(self):
        base = [10, 20, 30, 40]
        overlay = [7, 9, 7, 4]
        self.assertEqual([b if o == 7 else o for b, o in zip(base, overlay)], [10, 9, 30, 4])

    def test_collision_raw_mask(self):
        self.assertEqual(raw_collision(0, 2, 0, False, 0, 0x10), (0, 0x80, 0x11))
        self.assertEqual(raw_collision(0, 2, 0, False, 1, 0x10), (0, 0x201, 0x11))
        self.assertEqual(raw_collision(2, 1, 0, True, 0, 0x11), (1, 0x201, 0x10))
        self.assertEqual(raw_collision(2, 2, 0x40, False, 0, 0x11), (2, 0, 0x10))

    def test_godot_reference_entrypoints(self):
        source = (ROOT / "scripts/native_terrain_reference.gd").read_text()
        for symbol in ("func native_index(", "func sector(", "func attribute_at(", "func sample_four(", "func four_points("):
            self.assertIn(symbol, source)
        source = (ROOT / "scripts/native_collision_policy_reference.gd").read_text()
        self.assertIn("func resolve(", source)
        self.assertIn("0x201", source)

    def test_brush_transaction_shape(self):
        source = (ROOT / "scripts/island_composer.gd").read_text()
        self.assertIn("func set_land_area(", source)
        self.assertIn("var preview := IslandComposer.new(", source)
        self.assertIn("island = preview.island", source)
        self.assertIn('"BRUSH_OUTSIDE"', source)

    def test_editor_controls(self):
        source = (ROOT / "scripts/main.gd").read_text()
        self.assertIn("KEY_U:", source)
        self.assertIn("KEY_Y:", source)
        self.assertIn("NusantaraGroundQuery.sample_tile", source)


if __name__ == "__main__":
    unittest.main()
