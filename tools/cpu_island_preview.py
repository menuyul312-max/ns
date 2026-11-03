"""CPU diagnostic for Nusantara World Lab fixture_coast_mask (not a Godot render).

Reads the authored fixture parameters from `scripts/island_definition.gd` by
using their documented values. Does NOT execute GDScript, match its vertex
shader, or claim to reproduce mesh/collider/framebuffer exactly.
"""

from pathlib import Path
import math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT = Path(__file__).resolve().parents[1]
W, D = 20, 14
TILE, HEIGHT_STEP = 2.1, 1.55


def island_fixture():
    # Mirrors IslandDefinition.fixture_coast_mask from Godot source.
    land = np.ones((D, W), dtype=bool)
    height = np.zeros((D, W), dtype=np.int32)
    wet = np.zeros((D, W), dtype=bool)
    for z in range(D):
        for x in range(W):
            nx, nz = (x - 9.4) / 9.3, (z - 6.4) / 6.6
            radial = nx*nx + nz*nz
            wave = .085*math.sin(x*.72) + .067*math.sin(z*.83)
            missing = radial + wave > .93
            if x >= 14 and 4 <= z <= 9 and x + int(abs(z-6.5)) >= 16:
                missing = True
            if 8 <= x <= 9 and z >= 11:
                missing = True
            if x == 16 and z >= 9:
                missing = True
            land[z,x] = not missing
    for z in range(10,13):
        for x in range(17,20):
            if (x-18)**2 + (z-11)**2 <= 2:
                land[z,x] = True
    for z in range(2,6):
        for x in range(4,10):
            if land[z,x]:
                height[z,x]=1
    centers=[6,6,7,7,8,8,9,8,8]
    for n,center in enumerate(centers):
        z=n+2
        for x in (center,center+1):
            if land[z,x]:
                wet[z,x]=True
    return land,height,wet


def preview_stats():
    land, height, wet = island_fixture()
    return {
        "width":W,"depth":D,"land_tiles":int(land.sum()),
        "sea_tiles":int((~land).sum()),"cliff_tiles":int((height>0).sum()),
        "river_tiles":int(wet.sum()),
    }


def render(path=None):
    land,height,wet=island_fixture()
    colors={"grass":"#76a55b","sand":"#c9b785","cliff":"#8d7862", "sea":"#2385a2","river":"#47b9b9"}
    plt.rcParams.update({"font.family":"DejaVu Sans","figure.facecolor":"#102635", "savefig.facecolor":"#102635"})
    fig=plt.figure(figsize=(16,9),dpi=110)
    ax=fig.add_axes((0.02,0.08,0.69,0.83),projection="3d",computed_zorder=False)
    ax.set_facecolor("#102635")
    sea_poly=[(-TILE,-TILE,-.18),((W+1)*TILE,-TILE,-.18),((W+1)*TILE,(D+1)*TILE,-.18),(-TILE,(D+1)*TILE,-.18)]
    ax.add_collection3d(Poly3DCollection([sea_poly],facecolors=colors["sea"],alpha=.78,zorder=1))
    tops, top_cols, walls, wall_cols, streams = [],[],[],[] ,[]
    for z in range(D):
        for x in range(W):
            if not land[z,x]:
                continue
            h=height[z,x]*HEIGHT_STEP
            x0,x1=x*TILE,(x+1)*TILE
            y0,y1=z*TILE,(z+1)*TILE
            corners=[(x0,y0,h),(x1,y0,h),(x1,y1,h),(x0,y1,h)]
            tops.append(corners)
            coast = x in (0,W-1) or z in (0,D-1) or any(
                (not (0<=x+dx<W and 0<=z+dz<D)) or not land[z+dz,x+dx]
                for dx,dz in ((1,0),(-1,0),(0,1),(0,-1))
            )
            top_cols.append(colors["sand"] if coast and h==0 and not wet[z,x] else colors["grass"])
            if wet[z,x]:
                streams.append([(a,b,h+.055) for a,b,_ in corners])
            for dx,dz,edge in (
                (0,-1,(0,1)),(1,0,(1,2)),(0,1,(2,3)),(-1,0,(3,0))
            ):
                nx,nz=x+dx,z+dz
                nh=height[nz,nx]*HEIGHT_STEP if 0<=nx<W and 0<=nz<D and land[nz,nx] else -.23
                if h <= nh+.001:
                    continue
                a,b=corners[edge[0]],corners[edge[1]]
                walls.append([a,b,(b[0],b[1],nh),(a[0],a[1],nh)])
                wall_cols.append(colors["cliff"] if h>0 else colors["sand"])
    ax.add_collection3d(Poly3DCollection(walls,facecolors=wall_cols,edgecolors="#615e54",linewidths=.13,alpha=.97,zorder=3))
    ax.add_collection3d(Poly3DCollection(tops,facecolors=top_cols,edgecolors="#46744e",linewidths=.18,alpha=1,zorder=4))
    if streams:
        ax.add_collection3d(Poly3DCollection(streams,facecolors=colors["river"],edgecolors="none",alpha=.95,zorder=5))
    ax.set_xlim(-4, W*TILE+4)
    ax.set_ylim(-5, D*TILE+4)
    ax.set_zlim(-1, 10)
    ax.set_box_aspect((W*TILE,D*TILE,11),zoom=.93)
    ax.view_init(elev=38,azim=-64)
    ax.set_axis_off()

    top=fig.add_axes((.725,.19,.25,.62))
    layer=np.zeros((D,W),dtype=np.int8)
    layer[land]=1
    layer[height>0]=2
    layer[wet]=3
    top.imshow(layer,cmap=ListedColormap((colors["sea"],colors["grass"],"#bfb48a",colors["river"])),interpolation="nearest",vmin=0,vmax=3)
    top.invert_yaxis()
    top.set_xticks(np.arange(-.5,W,1),minor=True)
    top.set_yticks(np.arange(-.5,D,1),minor=True)
    top.grid(which="minor",color="#496e69",linewidth=.32)
    top.tick_params(which="both",bottom=False,left=False,labelbottom=False,labelleft=False)
    for spine in top.spines.values():
        spine.set_color("#b0c8c4")
    top.set_title("DENAH 2D YANG SAMA",color="white",fontsize=13,pad=14,fontweight="bold")

    fig.text(.03,.953,"NUSANTARA WORLD LAB 46  /  DIAGNOSTIC ISLAND OVERVIEW",color="white",fontsize=19,weight="bold")
    stats=preview_stats()
    fig.text(.735,.11,f'{stats["land_tiles"]} darat   •   {stats["sea_tiles"]} laut\n{stats["cliff_tiles"]} tebing   •   {stats["river_tiles"]} sungai',color="#cde6dd",fontsize=11,linespacing=1.8)
    fig.text(.03,.028,"PREVIEW CPU dari fixture_coast_mask • tanpa shader/noise/collision Godot • BUKAN capture game yang dijalankan",color="#f2c88f",fontsize=11)
    output=Path(path) if path else ROOT/'s46_island_cpu_preview.png'
    fig.savefig(output,facecolor=fig.get_facecolor(),dpi=110)
    plt.close(fig)
    return output


if __name__=='__main__':
    print(preview_stats())
    print(render())
