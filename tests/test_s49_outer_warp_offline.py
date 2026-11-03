"""CPU harmonic bounds for the outer coast; actual membership needs Godot."""

import math
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SEED=7219
FIRST=.34
SECOND=.135


def west_outer_wave(z):
    phase=(SEED % 307)*.019
    return FIRST*math.sin(z*.43+phase)+SECOND*math.sin(z*1.17-phase*.79)


class OuterWarpCPU(unittest.TestCase):
    def test_default_fixture_has_outward_segments(self):
        values=[west_outer_wave(29.4*i/300) for i in range(301)]
        self.assertLess(min(values),-.08)
        self.assertGreater(max(values),.08)

    def test_harmonics_fit_guard(self):
        values=[abs(west_outer_wave(i*.07)) for i in range(1000)]
        self.assertLessEqual(max(values),FIRST+SECOND+1e-10)
        source=(ROOT/'scripts/coast_contour.gd').read_text()
        self.assertIn('const OUTER_WARP_GUARD: float = 2.40',source)
        self.assertIn('var cell_x: int = clampi(floori(x / tile)',source)
        self.assertIn('var along_z: float = clampf(z, 0.0, d)',source)


if __name__=='__main__':
    unittest.main()
