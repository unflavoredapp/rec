import sys,math,json,os; sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy
from mathutils import Matrix
from PIL import Image
a=sys.argv[sys.argv.index('--')+1:]; gid=a[0]; body,gear,helm,head=[int(x) for x in a[1:5]]; hide=a[5] if len(a)>5 else ''
OUT='/tmp/gunwork/stf_out'; D=OUT+'/tex/'
for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
def imp(path):
    before={o.name for o in bpy.data.objects}; bpy.ops.import_scene.gltf(filepath=path); return [o for o in bpy.data.objects if o.name not in before]
parts=imp(OUT+'/stf_head.glb')+imp(f'{OUT}/stf_{gid}.glb')
tex={'body':f'stf_body_{body}','gear':f'stf_gear_{gear}','helm':f'stf_helm_{helm}','nvg':f'stf_helm_{helm}','head':f'stf_head_{head}'}
for o in parts:
    if o.type!='MESH': continue
    k=o.name.split('_STF')[0]
    if k in hide.split(','): o.hide_render=True; continue
    if k in tex:
        for sl in o.material_slots:
            for n in sl.material.node_tree.nodes:
                if n.type=='TEX_IMAGE': n.image=bpy.data.images.load(D+tex[k]+'.jpg'); n.image.colorspace_settings.name='sRGB'
    if k=='glass':
        for sl in o.material_slots:
            b=sl.material.node_tree.nodes['Principled BSDF']
            for l in list(sl.material.node_tree.links): sl.material.node_tree.links.remove(l)
            b.inputs['Base Color'].default_value=(0.03,0.03,0.04,1)
# gun
H=json.load(open(OUT+'/ophold_stf.json'))[gid]
before={o.name for o in bpy.data.objects}
bpy.ops.import_scene.gltf(filepath=f'/mnt/user-data/outputs/changed-files/Resources/gun_{gid}.glb')
names=[o.name for o in bpy.data.objects if o.name not in before]
for n in names:
    if n.endswith(('_glove','_sleeve','_ARMS','_strap')): bpy.data.objects.remove(bpy.data.objects[n],do_unlink=True)
new=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
em=bpy.data.objects.new('gr',None); bpy.context.collection.objects.link(em)
al,phi=H['al'],H['phi']
def Rx(t): c,s=math.cos(t),math.sin(t); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Ry(t): c,s=math.cos(t),math.sin(t); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
C=np.array([[1,0,0],[0,0,-1],[0,1,0]],float); Rg=Rx(al)@Ry(phi); Ra=C@Rg@C.T; pa=C@np.array(H['pos'])
em.matrix_world=Matrix(((*Ra[0],pa[0]),(*Ra[1],pa[1]),(*Ra[2],pa[2]),(0,0,0,1)))
for o in new:
    if o.parent is None: o.parent=em
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.cycles.device='CPU'
sc.render.resolution_x=700; sc.render.resolution_y=900
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=4
for ln,loc,rot,en in (('sun',(100,100,300),(0.8,0.2,0.5),3),):
    l=bpy.data.lights.new('s','SUN'); l.energy=en; lo=bpy.data.objects.new('s',l); bpy.context.collection.objects.link(lo); lo.rotation_euler=(0.7,0.2,2.6)
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=float(os.environ.get('SC','200'))
ims=[]
for loc,rot in (((0,500,float(os.environ.get('CZ','95'))),(90,0,180)),((-350,350,float(os.environ.get('CZ','95'))),(90,0,225)),((350,350,float(os.environ.get('CZ','95'))),(90,0,135))):
    cam.location=loc; cam.rotation_euler=[math.radians(x) for x in rot]
    sc.render.filepath='/tmp/gunwork/_k.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
W=Image.new('RGB',(2100,900)); [W.paste(im,(i*700,0)) for i,im in enumerate(ims)]
W.resize((1500,643)).save('/tmp/gunwork/stfc_%s.png'%gid)
