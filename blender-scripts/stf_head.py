import sys,math; sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L, numpy as np, bpy
from PIL import Image
r=L.load()
for o in bpy.data.objects:
    if o.name.startswith('cs_') or o.type in('EMPTY','ARMATURE'): o.hide_render=True
for n in ('Object_0','Object_1','Object_2'): r.obj[n]['o'].hide_render=True
hide2=len(sys.argv)>1 and sys.argv[-1]=='bare'
for n in ('Object_0','Object_1','Object_2'):
    if n=='Object_2' and hide2: continue
    L.emit(r,n,r.obj[n]['co'])
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.cycles.device='CPU'
sc.render.resolution_x=700; sc.render.resolution_y=700
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=4
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=45
ims=[]
for loc,rot in (((0,300,172),(90,0,180)),((300,0,172),(90,0,90)),((-250,200,172),(90,0,230))):
    cam.location=loc; cam.rotation_euler=[math.radians(a) for a in rot]
    sc.render.filepath='/tmp/gunwork/_h.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
W=Image.new('RGB',(2100,700))
for i,im in enumerate(ims): W.paste(im,(i*700,0))
W.resize((1500,500)).save('/tmp/gunwork/stf_head_%s.png'%('bare' if hide2 else 'full'))
