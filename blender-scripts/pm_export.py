import sys, json, os, math
sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy
import pm_prep, lib, gunarms2
from lib import reset, build_and_export
def qrot(q,v):
    x,y,z,w=q; u=np.array([x,y,z]); t=2*np.cross(u,v); return v+w*t+np.cross(u,t)
OUT='/tmp/gunwork/qout'
xf=json.load(open('/tmp/gunwork/xf.json')); meta=json.load(open(OUT+'/gunmeta.json'))
parts,s=pm_prep.load()
lib.OBJS.clear()
GRP={'Part03':('slide','QUAT'),'Part02':('slide','QUAT'),'Part01':('mag','QUAT'),'Part08':('','QUATP'),'Part04':('','QUAT'),
     'Part05':('','QUAT'),'Part09':('','QUAT'),'Part10':('','QUAT')}
for n,o in parts.items():
    g,mk=GRP[n]
    for sl in o.material_slots:
        m=sl.material
        if m and m.use_nodes:
            b=m.node_tree.nodes.get('Principled BSDF')
            if b: b.inputs['Alpha'].default_value=1.0; m.blend_method='OPAQUE' if hasattr(m,'blend_method') else None
    lib.OBJS.append((o,g,mk))
P=dict(rg=(-6.0,27.0),hd=3.0,pw=1.3,lmode='wrap',index=0.5,lx=1.1,ly=-2.4,lz=-1.2,lidx=0.8,lthumb=0.1,top=(3.0,19.5),st=3.4)
gunarms2.arms(P)
p=xf['pistol']; q=p['q']
gp=qrot(q,np.array([0,-6.0,16.8]))+np.array(p['mz'])        # pistol grip, exported space
T=gp-qrot(q,np.array([0,P['rg'][0],P['rg'][1]]))
xf['pm']={'q':q,'mz':[float(x) for x in T]}
build_and_export(f'{OUT}/gun_pm.glb',q,T,{})
R=lambda v:[round(float(x),4) for x in qrot(q,np.array(v,float))]
top=qrot(q,np.array([0,P['top'][0],P['top'][1]],float))+T
meta['pm']={'top':[round(float(x),3) for x in top],'mz':[round(float(x),3) for x in T],'anim':{'mag':R((0,-1,0)),'slide':R((0,0,1))},'st':P['st']}
json.dump(meta,open(OUT+'/gunmeta.json','w')); json.dump(xf,open('/tmp/gunwork/xf.json','w'))
print('pm ok',T)
