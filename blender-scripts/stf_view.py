import sys,math,json; sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy
import stf_lib as L, stf_pose as SP
from mathutils import Matrix
from PIL import Image
gid=sys.argv[sys.argv.index('--')+1]; extra=sys.argv[sys.argv.index('--')+2:]
r=L.load()
Ts,hold,G,info=SP.solve(r,gid)
for o in bpy.data.objects:
    if o.name.startswith('cs_') or o.type in('EMPTY','ARMATURE'): o.hide_render=True
for n in ('Object_0','Object_1','Object_2'):
    r.obj[n]['o'].hide_render=True
    co=L.skin(r,n,Ts) if n!='Object_2' else r.obj[n]['co']
    if n=='Object_2': co=L.skin(r,n,Ts)
    L.emit(r,n,co)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=f'/mnt/user-data/outputs/changed-files/Resources/gun_{gid}.glb')
names=[o.name for o in bpy.data.objects if o not in before]
for n in names:
    if n.endswith(('_glove','_sleeve','_ARMS','_strap')): bpy.data.objects.remove(bpy.data.objects[n],do_unlink=True)
new=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
em=bpy.data.objects.new('gunroot',None); bpy.context.collection.objects.link(em)
M=Matrix(((*G['Ra'][0],G['pa'][0]),(*G['Ra'][1],G['pa'][1]),(*G['Ra'][2],G['pa'][2]),(0,0,0,1))); em.matrix_world=M
for o in new:
    if o.parent is None: o.parent=em
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=20; sc.cycles.device='CPU'
sc.render.resolution_x=800; sc.render.resolution_y=800
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=5
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=float(extra[0]) if extra else 75
cz=float(extra[1]) if len(extra)>1 else 145
ims=[]
import os
if os.environ.get('HANDS'):
    tgt=bpy.data.objects.new('t',None); bpy.context.collection.objects.link(tgt)
    p=SP.P[gid]; gy,gz=p['rg']
    c=G['Pl'] if os.environ.get('HANDS')=='L' else G['Pc'] if os.environ.get('HANDS')=='R' else (np.array(G['P']((0,gy,gz)))+np.array(G['P']((0,p['lg'][1],p['lg'][0]) if p['lmode']!='wrap' else (0,gy,gz))))/2 if os.environ.get('HANDS')=='mid' else np.array(G['P']((0,gy,gz)))
    tgt.location=c
    tr=cam.constraints.new('TRACK_TO'); tr.target=tgt; tr.track_axis='TRACK_NEGATIVE_Z'; tr.up_axis='UP_Y'
    cam.data.ortho_scale=float(os.environ.get('HS','50'))
    for off in ((120,60,40),(-120,60,40),(0,150,10),(0,-60,150)):
        cam.location=c+np.array(off); bpy.context.view_layer.update()
        sc.render.filepath='/tmp/gunwork/_v.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
else:
  for loc,rot in (((0,300,cz),(90,0,180)),((300,0,cz),(90,0,90)),((-210,210,cz),(90,0,225)),((0,0,500),(0,0,0))):
    cam.location=loc; cam.rotation_euler=[math.radians(a) for a in rot]
    sc.render.filepath='/tmp/gunwork/_v.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
W=Image.new('RGB',(3200,800))
for i,im in enumerate(ims): W.paste(im,(i*800,0))
W.resize((1600,400)).save('/tmp/gunwork/stfv_%s%s.png'%(gid,'_h' if os.environ.get('HANDS') else ''))
