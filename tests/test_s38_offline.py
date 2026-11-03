"""CPU-only tests and a truthful illustrative shoreline-distance comparison.

Godot mesh rendering/physics must still be run in a real Godot binary.
"""

from pathlib import Path
from math import hypot
import random
import unittest

ROOT = Path(__file__).resolve().parents[1]
TILE = 2.1
FILLET = 0.72


def segment_squared(p, a, b):
    d = (b[0]-a[0], b[1]-a[1])
    squared = d[0]**2 + d[1]**2
    if squared < 1e-7:
        return (p[0]-a[0])**2 + (p[1]-a[1])**2
    t = min(1.0, max(0.0, ((p[0]-a[0])*d[0] + (p[1]-a[1])*d[1])/squared))
    return (p[0]-a[0]-t*d[0])**2 + (p[1]-a[1]-t*d[1])**2


def halo_contains(a, b, point, tile=TILE, halo=2):
    minx = int((min(a[0], b[0])) // tile) - halo
    maxx = int((max(a[0], b[0])) // tile) + halo
    minz = int((min(a[1], b[1])) // tile) - halo
    maxz = int((max(a[1], b[1])) // tile) + halo
    bx, bz = int(point[0] // tile), int(point[1] // tile)
    return minx <= bx <= maxx and minz <= bz <= maxz


class ShoreCacheSmoke(unittest.TestCase):
    def test_distance_to_segment(self):
        self.assertAlmostEqual(segment_squared((1, 1), (0, 0), (2, 0)), 1)
        self.assertAlmostEqual(segment_squared((5, 0), (0, 0), (2, 0)), 9)
        self.assertAlmostEqual(segment_squared((1, 1), (0, 0), (0, 0)), 2)

    def test_two_tile_halo_contains_beach_band(self):
        random.seed(36)
        for _ in range(400):
            a = random.uniform(0, 40), random.uniform(0, 40)
            b = a[0] + random.uniform(-2, 2), a[1] + random.uniform(-2, 2)
            r = random.uniform(0, 3.35)
            direction = random.uniform(0, 6.28)
            from math import cos, sin
            t = random.uniform(0, 1)
            middle = (a[0] + t*(b[0]-a[0]), a[1] + t*(b[1]-a[1]))
            point = middle[0]+r*cos(direction), middle[1]+r*sin(direction)
            self.assertTrue(halo_contains(a, b, point))

    def test_cache_honors_geometry_contract(self):
        coast = (ROOT / "scripts/coast_contour.gd").read_text()
        terrain = (ROOT / "scripts/terrain_builder.gd").read_text()
        self.assertIn("func prepare_shoreline_cache", coast)
        self.assertIn("TerrainBuilder._shore_edge_bounds(", coast)
        self.assertIn("TerrainBuilder._concave_arc_point(", coast)
        self.assertIn("_point_to_segment_squared(point, segments[index]", coast)
        self.assertIn("CoastContour.prepare_shoreline_cache(island)", terrain)
        self.assertIn("var bounds: Vector2 = _shore_edge_bounds(", terrain)

    def test_editor_mutations_invalidate_cache(self):
        definition = (ROOT / "scripts/island_definition.gd").read_text()
        for method in ("set_land", "set_height", "set_water", "set_coast_inset"):
            start = definition.index(f"func {method}(")
            end = definition.find("\nfunc ", start + 5)
            body = definition[start: end if end != -1 else len(definition)]
            self.assertIn("coastline_revision += 1", body, method)


def make_comparison():
    """Schematic: rasterized curved fillet vs box-distance on a toy island."""
    import numpy as np
    from scipy.ndimage import distance_transform_edt
    from PIL import Image, ImageDraw, ImageFont

    width, height, scale = 1120, 650, 65
    pixels = 510
    cols, rows = 7, 7
    sea = {(3, 2), (3, 3), (4, 3), (4, 4), (5, 4)}
    yy, xx = np.mgrid[0:pixels, 0:pixels]
    px_tile = pixels / cols
    gx, gz = xx / px_tile, yy / px_tile
    tile_x, tile_z = np.floor(gx).astype(int), np.floor(gz).astype(int)
    water = np.zeros((pixels, pixels), dtype=bool)
    for ix, iz in sea:
        water |= (tile_x == ix) & (tile_z == iz)
    old_land = ~water
    new_land = old_land.copy()
    for ix, iz in sea:
        for dx, dz in ((-1,-1), (1,-1), (1,1), (-1,1)):
            supports = ((ix+dx,iz), (ix,iz+dz), (ix+dx,iz+dz))
            if not all(0 <= x < cols and 0 <= z < rows and (x,z) not in sea for x,z in supports):
                continue
            x0 = ix + (1 if dx < 0 else 0)
            z0 = iz + (1 if dz < 0 else 0)
            local_x, local_z = (gx-x0)*dx, (gz-z0)*dz
            radius = FILLET / TILE
            pocket = (local_x >= 0) & (local_x <= radius) & (local_z >= 0) & (local_z <= radius)
            pocket &= np.hypot(local_x-radius, local_z-radius) >= radius
            new_land |= pocket
    canvas = Image.new('RGB', (width, height), '#0b1e2b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for i, (mask, label) in enumerate(((old_land, 'SPRINT 35: JARAK KE KOTAK TILE'),
                                       (new_land, 'SPRINT 38: JARAK KE GARIS PANTAI'))):
        dist = distance_transform_edt(mask) * TILE / px_tile
        blend = np.clip((dist-0.50)/2.85, 0, 1)[...,None]
        sand = np.array((211, 186, 127))
        grass = np.array((76, 145, 75))
        ocean = np.array((37, 116, 146))
        rgb = (sand[None,None,:]*(1-blend) + grass[None,None,:]*blend).astype('uint8')
        rgb[~mask] = ocean
        img = Image.fromarray(rgb, 'RGB')
        x, y = 23+i*564, 86
        canvas.paste(img, (x,y))
        for grid_i in range(cols+1):
            xx = x + int(grid_i*px_tile)
            draw.line((xx,y,xx,y+pixels), fill='#68827e',width=1)
        for grid_i in range(rows+1):
            zz = y + int(grid_i*px_tile)
            draw.line((x,zz,x+pixels,zz), fill='#68827e',width=1)
        draw.text((x, 43), label, font=font, fill='#f2f7f4')
    draw.text((24, 607), 'Diagram matematis: kondisi ilustratif tanpa mesh warp; bukan capture 3D Godot maupun screenshot ACNH.',
              fill='#c5dce4',font=font)
    out = ROOT / 's38_sandband_curve_diagnostic.png'
    canvas.save(out)
    return out


if __name__ == '__main__':
    unittest.main(exit=False)
    make_comparison()
