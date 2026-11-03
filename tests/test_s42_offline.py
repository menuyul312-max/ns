"""CPU-only shoreline continuity and surf-band checks.

Does not execute Godot shaders or physics; additionally creates an explanatory
non-rendered comparison image that may never be labeled a Godot screenshot.
"""

from pathlib import Path
import math
import random
import unittest

ROOT = Path(__file__).resolve().parents[1]
TILE = 2.1


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3-2*t)


def coherent_wave(t, world_z, phase, before, after):
    hump = math.sin(math.pi*t)**2
    continuity = (1.0 if before else 0.0)*(1-smoothstep(t)) + (1.0 if after else 0.0)*smoothstep(t)
    global_wave = .72*math.sin(world_z*.51+phase) + .28*math.sin(world_z*1.09-phase*.73)
    return (.40+.19*math.sin(world_z*.37+phase))*hump + .60*continuity*global_wave


def old_wave(t, world_z, phase):
    return math.sin(math.pi*t)*(.88+.12*math.sin(t*2*math.pi+phase))


def geometric_sdf_blend(raster, geometric):
    # The new surf shader narrows geometric computation to the visible band.
    if raster >= 3.85:
        return raster
    t = smoothstep((raster-2.10)/(3.85-2.10))
    return geometric*(1-t) + raster*t


class ShorelineContinuity(unittest.TestCase):
    def test_coherent_join_c0_and_c1(self):
        random.seed(39)
        eps = 0.00001
        for _ in range(100):
            phase = random.uniform(-5, 5)
            joint = TILE*random.randint(2, 12)
            left = coherent_wave(1, joint, phase, True, True)
            right = coherent_wave(0, joint, phase, True, True)
            self.assertAlmostEqual(left, right, places=9)
            left_derivative = (left-coherent_wave(1-eps, joint-eps*TILE, phase, True, True)) / (eps*TILE)
            right_derivative = (coherent_wave(eps, joint+eps*TILE, phase, True, True)-right) / (eps*TILE)
            self.assertLess(abs(left_derivative-right_derivative), 0.0003)

    def test_exposed_dead_end_does_not_shift_corner(self):
        for phase in (0, 1, 2.7):
            self.assertAlmostEqual(coherent_wave(0, 6.3, phase, False, True), 0.0)
            self.assertAlmostEqual(coherent_wave(1, 8.4, phase, True, False), 0.0)
            self.assertLessEqual(abs(coherent_wave(.5, 7.3, phase, True, True)), 1.3)

    def test_surf_field_refines_visible_waves_only(self):
        for raster in (0.0, .5, 2.0):
            self.assertAlmostEqual(geometric_sdf_blend(raster, .41), .41)
        self.assertAlmostEqual(geometric_sdf_blend(3.85, .41), 3.85)
        self.assertGreater(geometric_sdf_blend(3.1, .41), .41)
        self.assertLess(geometric_sdf_blend(3.1, .41), 3.1)

    def test_godot_entrypoints_are_shared(self):
        coast = (ROOT/'scripts/coast_contour.gd').read_text()
        sea = (ROOT/'scripts/coast_builder.gd').read_text()
        self.assertIn('static func _same_vertical_bank(', coast)
        self.assertIn('static func _same_horizontal_bank(', coast)
        self.assertIn('static func _coherent_seam_wave(', coast)
        self.assertIn('var local_hump: float = pow(sin(PI * along), 2.0)', coast)
        self.assertIn('CoastContour.distance_to_coast(island, wx, wz)', sea)
        self.assertIn('GEOMETRIC_SDF_BLEND_END', sea)
        self.assertIn('static func _edt_1d(', sea)


def make_continuity_capture():
    from PIL import Image, ImageDraw, ImageFont
    W,H=1200,650
    frame=Image.new('RGB',(W,H),'#0b1b27')
    draw=ImageDraw.Draw(frame)
    font=ImageFont.load_default()
    labels=('SPRINT 38 / GELOMBANG ULANG PER TILE', 'SPRINT 42 / LEKUKAN MULTI-TILE KONTINU')
    count=8
    for panel in range(2):
        x0=28+panel*600; y0=88; pw=545; ph=440
        draw.rectangle((x0,y0,x0+pw,y0+ph),fill='#214d62')
        for row in range(count):
            y=y0+int(row*ph/count)
            draw.line((x0,y,x0+pw,y),fill='#6b8190',width=1)
        phase=1.1
        bx=x0+pw*.48
        points=[]
        for sample in range(1001):
            frac=sample/1000.0
            z=frac*count*TILE
            cell=min(count-1,int(z/TILE))
            t=z/TILE-cell
            if panel==0:
                w=old_wave(t,z,phase)
            else:
                # Endpoints are pinned to dry corners; all inner joints are
                # continuous. Exaggerate lateral relief to show curvature.
                w=coherent_wave(t,z,phase,cell>0,cell<count-1)
            x=bx+w*95
            y=y0+ph*frac
            points.append((x,y))
        # Color land left of the boundary and a narrow sand fringe.
        for idx in range(len(points)-1):
            xa,ya=points[idx]
            xb,yb=points[idx+1]
            draw.polygon(((x0,ya),(xa,ya),(xb,yb),(x0,yb)),fill='#5a945b')
            draw.line(((xa,ya),(xb,yb)),fill='#eed59b',width=7)
        draw.line(points,fill='#10272d',width=2)
        for row in range(1,count):
            joint_y=y0+int(row*ph/count)
            draw.line((x0,joint_y,x0+pw,joint_y),fill='#c4d3d7',width=1)
            if panel==0:
                draw.ellipse((bx-3,joint_y-3,bx+3,joint_y+3),fill='#f8db68')
        draw.text((x0,42),labels[panel],fill='#ecf8f2',font=font)
        draw.text((x0,y0+ph+15),'Hijau: darat     Biru: laut     Kuning: garis pantai',fill='#bcd1d5',font=font)
    draw.text((28,594),'DIAGNOSTIK ANALITIK — skala deformasi horizontal diperbesar untuk penjelasan. Bukan render Godot/ACNH.',fill='#c8dde2',font=font)
    target=ROOT/'s42_coherent_coastline_diagnostic.png'
    frame.save(target)
    return target


if __name__=='__main__':
    unittest.main(exit=False)
    make_continuity_capture()
