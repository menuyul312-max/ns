"""Standard-library regression for Nusa GLB weight and template validation."""

import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_character_glb import load_profile, validate_skin


class CharacterAuditTests(unittest.TestCase):
    def test_normalized_four_influences(self):
        result = validate_skin([(0, 1, 2, 3)], [(0.4, 0.3, 0.2, 0.1)], 4)
        self.assertEqual(result["invalid_joint_vertices"], 0)
        self.assertEqual(result["unnormalized_vertices"], 0)
        self.assertEqual(result["max_influences"], 4)

    def test_invalid_weights_and_out_of_range_bones(self):
        result = validate_skin([(0, 8, 0, 0)], [(0.5, 0.4, 0.0, 0.0)], 4)
        self.assertEqual(result["invalid_joint_vertices"], 1)
        self.assertEqual(result["unnormalized_vertices"], 1)

    def test_inherited_profiles_require_added_anatomy(self):
        root = Path(__file__).resolve().parents[1] / "data/characters/profiles"
        animal = load_profile(root / "animal_biped.json")
        spirit = load_profile(root / "winged_spirit.json")
        self.assertIn("Hand_R", animal["aliases"])
        self.assertIn("Tail", animal["aliases"])
        self.assertIn("Root", spirit["required_roles"])
        self.assertIn("Wing_L", spirit["required_roles"])
        self.assertIn("Wing_R", spirit["required_roles"])


if __name__ == "__main__":
    unittest.main()
