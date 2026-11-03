"""CPU fixture/projection regression, not a substitute for Godot tests."""

from pathlib import Path
import sys
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from cpu_island_preview import island_fixture, region_diagnostic


class RegionDiagnosticCPU(unittest.TestCase):
    def test_all_masks_accounted(self):
        land, _, wet = island_fixture()
        for mode in (0, 1):
            status = region_diagnostic(mode)
            self.assertEqual(status.shape, land.shape)
            self.assertEqual(int((status == 0).sum()), int((~land).sum()))
            self.assertEqual(int((status == 1).sum()), int(wet.sum()))
            self.assertEqual(int((status >= 2).sum()), int((land & ~wet).sum()))

    def test_overlay_changes_only_the_bounded_diagnostic(self):
        mode0 = region_diagnostic(0)
        mode1 = region_diagnostic(1)
        self.assertEqual(int((mode0 == 2).sum()), 37)
        self.assertEqual(int((mode1 == 2).sum()), 50)
        self.assertTrue(np.any(mode0 != mode1))
        self.assertTrue(np.array_equal(mode0 == 0, mode1 == 0))
        self.assertTrue(np.array_equal(mode0 == 1, mode1 == 1))

    def test_godot_integration_is_opt_in_and_read_only(self):
        source = (ROOT / "scripts/main.gd").read_text()
        diagnostic = (ROOT / "scripts/terrain_region_diagnostic.gd").read_text()
        self.assertIn("show_region_diagnostic: bool = false", source)
        self.assertIn("KEY_J:", source)
        self.assertIn("KEY_H:", source)
        self.assertIn("NativeTerrainRegionReference.new", diagnostic)
        self.assertIn("synthetic_nusantara_projection", diagnostic)


if __name__ == "__main__":
    unittest.main()
