import sys,math; sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L, numpy as np, bpy
r=L.load()
# remove originals, render posed pistol-ish hold
gun=np.array([14.0,22.0,126.0])
Ts={}
Ts.update(L.pose_arm(r,'r',gun+np.array([2,-4,3]),(0.1,0.3,-1),(-1,0.4,0),(0.6,-0.2,-1),{'index':0.5,'middle':1,'ring':1,'pinky':1},0.6))
Ts.update(L.pose_arm(r,'l',gun+np.array([-2,-3,0]),(0,0.3,-1),(1,0.3,0),(-0.6,-0.2,-1),{'index':0.8,'middle':0.9,'ring':0.9,'pinky':0.9},0.3))
for n in ('Object_0','Object_1','Object_2'):
    d=r.obj[n]; 
    if n!='Object_2': L.emit(r,n,L.skin(r,n,Ts))
    else: L.emit(r,n,d['co'])
    d['o'].hide_render=True; d['o'].hide_viewport=True
for o in bpy.data.objects:
    if o.name.startswith('cs_') or o.type in('EMPTY','ARMATURE'): o.hide_render=True
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=16; sc.cycles.device='CPU'
sc.render.resolution_x=900; sc.render.resolution_y=900
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=4
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=150
ims=[]
from PIL import Image
for nm,loc,rot in (('front',(0,300,110),(90,0,180)),('side',(300,0,110),(90,0,90)),('top',(0,20,400),(0,0,0))):
    cam.location=loc; cam.rotation_euler=[math.radians(a) for a in rot]
    sc.render.filepath=f'/tmp/gunwork/_t1.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
W=Image.new('RGB',(2700,900))
for i,im in enumerate(ims): W.paste(im,(i*900,0))
W.resize((1800,600)).save('/tmp/gunwork/stf_t1.png')
