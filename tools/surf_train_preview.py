"""Independent CPU diagram of the authored Sprint50 wave-train equations.

No Godot execution, shader compilation, ACNH image or native code is involved.
The diagram uses a synthetic curved coast instead of the real terrain SDF.
"""

from pathlib import Path
import math
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SURF_TRAIN_RATE = 0.115


def smoothstep(low, high, value):
    t = np.clip((np.asarray(value)-low)/(high-low), 0.0, 1.0)
    return t*t*(3.0-2.0*t)


def wave_train(progress, distance, curvature=0.0):
    progress = np.asarray(progress)
    center = 2.38 + (0.18-2.38)*progress + curvature
    width = 0.14+(0.30-0.14)*progress
    crest = np.exp(-((np.asarray(distance)-center)/width)**2)
    birth = smoothstep(0.01, 0.17, progress)
    breakup = 1.0-smoothstep(0.79, 0.99, progress)
    return crest*birth*breakup


def crest_distance(progress):
    return 2.38-2.20*np.asarray(progress)


def render(path=None):
    from PIL import Image, ImageDraw, ImageFont
    panel_w, panel_h = 430, 420
    border, top, bottom = 35, 90, 74
    canvas = Image.new("RGB", (panel_w*4+border*2, panel_h+top+bottom), "#0f2635")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    times=(0.0, 2.2, 4.4, 6.6)
    yy, xx = np.mgrid[0:panel_h, 0:panel_w]
    z = yy*0.064
    boundary = 116.0 + 23*np.sin(z*0.44+0.7) + 12*np.sin(z*0.98-0.5)
    distance = (xx-boundary)*0.035
    for i, time in enumerate(times):
        along = z
        phase_variation = 0.035*np.sin(along*0.61) + 0.012*np.sin(along*1.33)
        progress = np.mod(time*SURF_TRAIN_RATE + phase_variation,1.0)
        curvature = 0.12*np.sin(z*0.88+0.3)
        main=wave_train(progress,distance,curvature)
        companion=wave_train(np.mod(progress+0.5,1.0),distance,curvature*0.76)
        coast_gate=smoothstep(0.02,0.13,distance)*(1.0-smoothstep(0.05,3.25,distance))
        patches=(np.sin(z*2.8+np.sin(xx*0.095))*np.cos(xx*0.072-z*0.88)+1.0)/2.0
        fracture=0.15+0.85*smoothstep(0.26,0.78,patches)
        foam=np.clip(coast_gate*(main+0.72*companion)*fracture,0,1)
        shallow=1.0-smoothstep(0.0,3.5,distance)
        sea=np.stack((24+24*shallow, 89+50*shallow, 123+25*shallow),axis=-1)
        sea=np.broadcast_to(sea,(panel_h,panel_w,3)).copy().astype(float)
        sea=sea*(1-foam[...,None]*0.73)+np.array([222,245,229])*foam[...,None]*0.73
        sand=(distance>=-0.34)&(distance<0)
        land=(distance<-0.34)
        sea[sand]=np.array([220,194,132])
        sea[land]=np.array([100,155,89])
        image=Image.fromarray(np.clip(sea,0,255).astype('uint8'),'RGB')
        x0=border+i*panel_w
        canvas.paste(image,(x0,top))
        draw.text((x0+12,top-29),f"t = {time:.1f}s",font=font,fill="#e4f7ef")
        draw.text((x0+12,top+panel_h+15),"Green = land     White = generated foam",font=font,fill="#c3dcdf")
        if i>0:
            draw.line((x0,top-35,x0,top+panel_h+2),fill="#466270",width=2)
    draw.text((border,36),"SPRINT 50 / TRAVELING COASTAL BREAKERS — FOUR CPU FRAMES",font=font,fill="#ffffff")
    draw.text((border,top+panel_h+48),"DIAGNOSTIC CPU • synthetic coast & authored wave equations • NOT GODOT or ACNH gameplay capture",font=font,fill="#f0c78e")
    target=Path(path) if path else ROOT/"s50_surf_train_cpu_frames.png"
    canvas.save(target)
    return target


if __name__ == "__main__":
    print(render())
