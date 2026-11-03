"""CPU-only cross-section comparison of original Nusantara cliff profiles.

Not a Godot render, not a reverse-engineered ACNH mesh, and not an authoritative
collision silhouette. It visualizes the same continuous 1D authored formulas.
"""

from pathlib import Path
import math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
SEED=7219


def width_at(along,side=3,enhanced=True):
    seed=(SEED%233)*.01
    if enhanced:
        return .125+.053*np.sin(along*5.3+side*1.7+seed)+.024*np.sin(along*11.7+side*3.5+seed)
    return .12+.041*np.sin(along*5.3+side*1.7+seed)+.02*np.sin(along*11.7+side*3.5+seed)


def wall_at(along,depth,side=3,enhanced=True):
    seed=(SEED%233)*.01
    lip=width_at(along,side,enhanced)
    belly=.135*np.sin(depth*np.pi)*(.78+.22*np.sin(along*3.1+side*.8+seed))
    facets=(.038*np.sin(along*5.6+depth*2.1+seed)+.017*np.sin(along*11.4-depth*4.7-seed))*np.sin(depth*np.pi)
    result=lip*(1-depth)+belly+facets
    if enhanced:
        upper=.31+.045*np.sin(along*2.4+seed)
        lower=.73+.035*np.cos(along*1.8-seed)
        ledge=np.exp(-((depth-upper)/.12)**2)
        lower_ledge=np.exp(-((depth-lower)/.105)**2)
        joint=np.exp(-((depth-.56)/.08)**2)
        result+=.08*(ledge+.55*lower_ledge-.42*joint)*np.sin(depth*np.pi)
    return result


def render(path=None):
    plt.rcParams.update({'font.family':'DejaVu Sans','figure.facecolor':'#142c36','savefig.facecolor':'#142c36'})
    fig,axes=plt.subplots(1,2,figsize=(13.6,6.0),dpi=130)
    d=np.linspace(0,1,301)
    for axis,enhanced,label in zip(axes,(False,True),('SPRINT 46 • SIMPLE FACE','SPRINT 54 • STRATIFIED LEDGES')):
        axis.set_facecolor('#183d48')
        for i,along in enumerate((3.0,3.27,3.53,3.81)):
            level=1.55*(1-d)
            wall=wall_at(along,d,enhanced=enhanced)
            axis.plot(wall,level,color=('#7ed5cf','#efc789','#e19e71','#f0dbb0')[i],lw=2.4,label=f'world x {along:.2f}')
        lip=float(width_at(3.53,enhanced=enhanced))
        axis.fill_betweenx([0,1.55],[-0.36,-0.36],[0,lip],color='#927253',alpha=.3)
        axis.plot([-0.35,lip],[1.55,1.55],color='#84c777',lw=6,solid_capstyle='round')
        axis.axvline(0,color='#537080',lw=1,ls='--')
        axis.set_xlim(-.08,.47)
        axis.set_ylim(-.04,1.75)
        axis.grid(color='#44717b',alpha=.26)
        axis.set_xlabel('Relief batu ke depan (unit)',color='#dae8e2',fontsize=11)
        axis.set_ylabel('Ketinggian relatif tebing',color='#dae8e2',fontsize=11)
        axis.tick_params(colors='#d2e1d9')
        axis.set_title(label,color='white',fontsize=14,fontweight='bold',pad=15)
        axis.legend(facecolor='#193543',edgecolor='#376470',labelcolor='#d4e7e7',fontsize=8,loc='upper right')
        for spine in axis.spines.values():
            spine.set_color('#47717b')
    fig.suptitle('NUSANTARA WORLD LAB • CLIFF FACE PROFILE / BEFORE vs AFTER',color='white',fontsize=16,fontweight='bold',y=.99)
    fig.text(.05,.015,'DIAGRAM CPU — penampang matematis 1D; kedua versi melekat ke bibir rumput dan tanah bawah. BUKAN render Godot/ACNH.',color='#f1c992',fontsize=9)
    fig.subplots_adjust(left=.08,right=.98,top=.84,bottom=.17,wspace=.21)
    output=Path(path) if path else ROOT/'s54_cliff_profile_cpu.png'
    fig.savefig(output,dpi=130)
    plt.close(fig)
    return output


if __name__=='__main__':
    print(render())
