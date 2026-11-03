"""Offline math/structural smoke tests and honest CPU-only topology diagram.

This file does not run Godot or claim to render the Godot 3D scene. It covers
the original concave-fillet geometry and Euclidean distance-transform idea.
"""

from math import cos, sin, pi, hypot
from pathlib import Path
import random
import unittest


ROOT = Path(__file__).resolve().parents[1]
RADIUS = 0.72
TILE = 2.1


def squared_edt(samples, spacing):
    n = len(samples)
    v = [0] * n
    z = [-1e20] + [1e20] * n
    k = 0
    ss = spacing * spacing
    for q in range(1, n):
        old = v[k]
        s = (samples[q] - samples[old] + (q*q - old*old)*ss) / (2 * (q-old) * ss)
        while k > 0 and s <= z[k]:
            k -= 1
            old = v[k]
            s = (samples[q] - samples[old] + (q*q - old*old)*ss) / (2 * (q-old) * ss)
        k += 1
        v[k] = q
        z[k] = s
        z[k+1] = 1e20
    out = [0.0] * n
    k = 0
    for q in range(n):
        while z[k+1] < q:
            k += 1
        out[q] = (q - v[k])**2 * ss + samples[v[k]]
    return out


def fillet_contains(lx, lz, radius=RADIUS):
    return 0 <= lx <= radius and 0 <= lz <= radius and hypot(lx-radius, lz-radius) >= radius


class ShorelineSmoke(unittest.TestCase):
    def test_edt_known_distance(self):
        self.assertEqual(squared_edt([1e8, 1e8, 0, 1e8, 1e8], 2.0), [16.0, 4.0, 0.0, 4.0, 16.0])

    def test_edt_matches_brute_force(self):
        random.seed(33)
        for length in (3, 11, 32):
            for spacing in (0.13, 0.73, 2.0):
                for _ in range(12):
                    values = [random.uniform(0, 6.0) if random.random() < 0.3 else 1e8 for _ in range(length)]
                    values[length//2] = 0.0
                    actual = squared_edt(values, spacing)
                    expected = [min(values[j] + ((i-j)*spacing)**2 for j in range(length)) for i in range(length)]
                    self.assertTrue(all(abs(x-y) < 1e-5 for x, y in zip(actual, expected)))

    def test_fillet_has_curved_boundary_not_square_fill(self):
        self.assertTrue(fillet_contains(0.05, 0.05))
        self.assertTrue(fillet_contains(0.2, 0.0))
        self.assertFalse(fillet_contains(RADIUS, RADIUS))
        self.assertFalse(fillet_contains(0.7, 0.7))

    def test_collidable_mesh_and_movement_shared(self):
        terrain = (ROOT / 'scripts/terrain_builder.gd').read_text()
        coast = (ROOT / 'scripts/coast_contour.gd').read_text()
        self.assertIn('_add_concave_shore_fillet(ground_tool, shore_skirt_tool', terrain)
        self.assertIn('collision_mesh in [ground_mesh, cliff_mesh]', terrain)
        self.assertIn('TerrainBuilder.on_concave_fillet(', coast)
        self.assertIn('func _is_concave_mask_corner(', terrain)


def generate_diagram():
    from PIL import Image, ImageDraw, ImageFont
    width, height, scale = 1200, 620, 53
    frame = Image.new('RGB', (width, height), '#0a1724')
    draw = ImageDraw.Draw(frame)
    font = ImageFont.load_default()
    for panel in range(2):
        ox, oy = (28 + panel * 606), 85
        for tz in range(7):
            for tx in range(9):
                is_sea = (tx, tz) in {(3, 2), (4, 2), (4, 3), (5, 2), (5, 3), (6, 3), (6, 4), (7, 4)}
                color = '#217b99' if is_sea else '#6da660'
                draw.rectangle((ox+tx*scale, oy+tz*scale, ox+(tx+1)*scale, oy+(tz+1)*scale), fill=color)
        if panel == 1:
            sea = {(3, 2), (4, 2), (4, 3), (5, 2), (5, 3), (6, 3), (6, 4), (7, 4)}
            for cx, cz in sea:
                for sx, sz in ((-1,-1),(1,-1),(1,1),(-1,1)):
                    if not all((cx+dx, cz+dz) not in sea and 0 <= cx+dx < 9 and 0 <= cz+dz < 7 for dx,dz in ((sx,0),(0,sz),(sx,sz))):
                        continue
                    base_x = ox + (cx+(1 if sx<0 else 0))*scale
                    base_z = oy + (cz+(1 if sz<0 else 0))*scale
                    rr = scale*RADIUS/TILE
                    pts = [(base_x, base_z)]
                    for index in range(31):
                        t = index/30
                        angle = -pi*0.5 - pi*0.5*t
                        pts.append((base_x+sx*rr*(1+cos(angle)), base_z+sz*rr*(1+sin(angle))))
                    draw.polygon(pts, fill='#d5ba78')
        # Grid guides show explicitly that the logical tile topology is unchanged.
        for i in range(10):
            x = ox+i*scale
            draw.line((x,oy,x,oy+7*scale),fill='#43606a',width=1)
        for j in range(8):
            y = oy+j*scale
            draw.line((ox,y,ox+9*scale,y),fill='#43606a',width=1)
        draw.text((ox, 39), 'SPRINT 32: MASK TILE SUDUT TAJAM' if panel == 0 else 'SPRINT 35: FILLET KONKAF',fill='white',font=font)
    draw.text((28, 507), 'Visual DIAGNOSTIK dari geometri matematis. Ini bukan hasil render 3D Godot atau capture ACNH.', fill='#cbdfe5',font=font)
    draw.text((28, 532), 'Lengkungan hanya di pojok yang didukung tiga sel darat. Bukan pola mesh hasil decompile.', fill='#a8cad0',font=font)
    frame.save(ROOT / 's35_fillet_topdown_schematic.png')


if __name__ == '__main__':
    unittest.main(exit=False)
    generate_diagram()
