"""Independent mathematical checks for rock ledge/no-crack design."""

import math
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SEED=7219


def lip(x,t,side=3):
    s=(SEED%233)*.01
    w=x+t
    return .125+.053*math.sin(w*5.3+side*1.7+s)+.024*math.sin(w*11.7+side*3.5+s)


def wall(x,t,d,side=3):
    along=x+t
    s=(SEED%233)*.01
    l=lip(x,t,side)
    belly=.135*math.sin(d*math.pi)*(.78+.22*math.sin(along*3.1+side*.8+s))
    facets=(.038*math.sin(along*5.6+d*2.1+s)+.017*math.sin(along*11.4-d*4.7-s))*math.sin(d*math.pi)
    upper=.31+.045*math.sin(along*2.4+s)
    lower=.73+.035*math.cos(along*1.8-s)
    ledge=math.exp(-((d-upper)/.12)**2)
    ledge2=math.exp(-((d-lower)/.105)**2)
    joint=math.exp(-((d-.56)/.08)**2)
    strata=.08*(ledge+.55*ledge2-.42*joint)*math.sin(d*math.pi)
    return l*(1-d)+belly+facets+strata


class CliffProfileCPU(unittest.TestCase):
    def test_joined_endpoints_and_shared_tile_boundary(self):
        for tile in range(2,14):
            for sample in range(13):
                d=sample/12
                self.assertAlmostEqual(wall(tile,1,d),wall(tile+1,0,d),places=12)
                self.assertAlmostEqual(wall(tile,.35,0),lip(tile,.35),places=12)
                self.assertAlmostEqual(wall(tile,.35,1),0,places=12)

    def test_relief_is_bounded_and_varied(self):
        values=[wall(4,i/50,j/12) for i in range(51) for j in range(13)]
        self.assertGreater(max(values)-min(values),.20)
        self.assertLess(max(values),.45)
        self.assertGreater(min(values),-.09)

    def test_godot_source_uses_world_seam_and_new_profiles(self):
        code=(ROOT/'scripts/terrain_builder.gd').read_text()
        self.assertIn('const WALL_ROWS: int = 12',code)
        self.assertIn('const CORNER_ARC_MIX: float = 0.54',code)
        self.assertIn('CLIFF_LEDGE_HEIGHT',code)
        self.assertIn('var upper_ledge:',code)


if __name__=='__main__':
    unittest.main()
