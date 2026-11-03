"""Topology ring invariants; mirrors Godot trace as an independent CPU QA.

This is mathematical verification, not proof that GDScript ran or rendered.
"""

from pathlib import Path
import random
import unittest
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT / 'tools'))
from cpu_island_preview import island_fixture, preview_stats


def trace(mask):
    depth=len(mask)
    width=len(mask[0])
    def land(x,z):
        return 0<=x<width and 0<=z<depth and bool(mask[z][x])
    edges=[]
    nexts={}
    def add(a,b):
        idx=len(edges)
        edges.append((a,b))
        nexts.setdefault(a,[]).append(idx)
    for z in range(depth):
        for x in range(width):
            if not land(x,z):
                continue
            if not land(x,z-1):add((x,z),(x+1,z))
            if not land(x+1,z):add((x+1,z),(x+1,z+1))
            if not land(x,z+1):add((x+1,z+1),(x,z+1))
            if not land(x-1,z):add((x,z+1),(x,z))
    visited=set()
    rings=[]
    broken=0
    for start in range(len(edges)):
        if start in visited:
            continue
        begin=edges[start][0]
        index=start
        ring=[]
        closed=False
        for _ in range(len(edges)+1):
            if index in visited:
                break
            visited.add(index)
            a,b=edges[index]
            ring.append(a)
            if b==begin:
                closed=True
                break
            incoming=(b[0]-a[0],b[1]-a[1])
            right=(-incoming[1],incoming[0])
            left=(incoming[1],-incoming[0])
            choices=[]
            for nxt in nexts.get(b,[]):
                if nxt in visited:
                    continue
                candidate=edges[nxt][1]
                direction=(candidate[0]-b[0],candidate[1]-b[1])
                priority=0 if direction==right else 1 if direction==incoming else 2 if direction==left else 3
                choices.append((priority,nxt))
            if not choices:
                break
            index=min(choices)[1]
        if not closed:
            broken+=1
            continue
        area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1]))/2
        rings.append((ring,area))
    return {
        'rings':rings,'islands':sum(a>0 for _,a in rings),
        'holes':sum(a<0 for _,a in rings),
        'area':sum(a for _,a in rings),
        'broken':broken,'edges':len(edges),'visited':len(visited)
    }


class GlobalTopologyTests(unittest.TestCase):
    def check(self, mask):
        info=trace(mask)
        self.assertEqual(info['broken'],0)
        self.assertEqual(info['visited'],info['edges'])
        self.assertEqual(info['area'],sum(int(bool(c)) for row in mask for c in row))
        return info

    def test_rectangle_and_hole(self):
        mask=[[1]*4 for _ in range(4)]
        info=self.check(mask)
        self.assertEqual((info['islands'],info['holes']), (1,0))
        mask[1][1]=0
        info=self.check(mask)
        self.assertEqual((info['islands'],info['holes']), (1,1))

    def test_diagonal_contact_stays_separate(self):
        info=self.check([[1,0],[0,1]])
        self.assertEqual((info['islands'],info['holes']), (2,0))

    def test_fixture_coast_mask_from_project(self):
        land, _, _=island_fixture()
        info=self.check(land)
        stats=preview_stats()
        self.assertEqual(stats['land_tiles'],159)
        self.assertGreaterEqual(info['islands'],2)

    def test_area_and_closedness_random_masks(self):
        random.seed(46)
        for _ in range(270):
            w=random.randint(2,15)
            h=random.randint(2,12)
            mask=[[random.random()>.35 for _x in range(w)] for _z in range(h)]
            self.check(mask)

    def test_gdscript_loop_contract_and_capture(self):
        source=(ROOT/'scripts/island_coast_loops.gd').read_text()
        main=(ROOT/'scripts/main.gd').read_text()
        capture=(ROOT/'tests/capture_sprint46.gd').read_text()
        self.assertIn('class_name IslandCoastLoops',source)
        self.assertIn('_choose_next',source)
        self.assertIn('"signed_area_world": signed_area',source)
        self.assertIn('coast_audit = IslandCoastLoops.trace(island)',main)
        self.assertIn('s46_godot_island_overview.png',capture)
        self.assertIn('s46_godot_contour_debug.png',capture)


def draw_audit():
    import numpy as np
    from PIL import Image,ImageDraw,ImageFont
    land, height, wet=island_fixture()
    info=trace(land)
    width,height_px,scale=1420,800,38
    canvas=Image.new('RGB',(width,height_px),'#0b1e2b')
    draw=ImageDraw.Draw(canvas)
    font=ImageFont.load_default()
    ox,oz=55,98
    for z in range(land.shape[0]):
        for x in range(land.shape[1]):
            color='#67a660' if land[z,x] else '#247e9b'
            if land[z,x] and height[z,x]>0:color='#a79d7b'
            if wet[z,x]:color='#43c1c2'
            draw.rectangle((ox+x*scale,oz+z*scale,ox+(x+1)*scale,oz+(z+1)*scale),fill=color)
    for ring,area in info['rings']:
        pts=[(ox+x*scale,oz+z*scale) for x,z in ring]
        pts.append(pts[0])
        color='#ffe5a8' if area>0 else '#f1777b'
        draw.line(pts,fill=color,width=4,joint='curve')
    draw.text((55,44),'SPRINT 46 / COAST TOPOLOGY RINGS FROM NUSANTARA FIXTURE',fill='white',font=font)
    sx=895
    draw.text((sx,114),'Batas mask pulau (bukan mesh 3D)',fill='#f2fbf2',font=font)
    draw.text((sx,160),f'Area darat: {info["area"]} tile',fill='#bce3ce',font=font)
    draw.text((sx,192),f'Pulau / komponen: {info["islands"]}',fill='#bce3ce',font=font)
    draw.text((sx,224),f'Cekungan dalam (hole): {info["holes"]}',fill='#bce3ce',font=font)
    draw.text((sx,256),f'Tepi tercakup: {info["visited"]}/{info["edges"]}',fill='#bce3ce',font=font)
    draw.text((sx,288),f'Rantai terbuka: {info["broken"]}',fill='#bce3ce',font=font)
    draw.line(((sx,355),(sx+50,355)),fill='#ffe5a8',width=5)
    draw.text((sx+62,350),'cincin luar / pulau',fill='white',font=font)
    draw.line(((sx,390),(sx+50,390)),fill='#f1777b',width=5)
    draw.text((sx+62,385),'cincin lubang air',fill='white',font=font)
    draw.text((55,692),'DIAGNOSTIK 2D: cincin dari sel land_mask, bukan shoreline mesh yang telah di-warp atau screenshot Godot.',fill='#cfdee4',font=font)
    target=ROOT/'s46_global_contour_audit.png'
    canvas.save(target)
    return target


if __name__=='__main__':
    unittest.main(exit=False)
    draw_audit()
