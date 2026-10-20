import sys,math,json,os; sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy
from mathutils import Matrix
from PIL import Image
OUT='/tmp/gunwork/stf_out'; D=OUT+'/tex/'; PO=OUT+'/portraits'; os.makedirs(PO,exist_ok=True)
LENS=[None,(0.03,0.03,0.04),(0.55,0.32,0.05),(0.05,0.15,0.4),(0.5,0.05,0.04)]
# name: (gun, body, gear, helmCol, head, face, lens, vest)
KITS=json.load(open('/tmp/gunwork/stf_kits.json'))
only=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(KITS)
def imp(path):
    before={o.name for o in bpy.data.objects}; bpy.ops.import_scene.gltf(filepath=path); return [o for o in bpy.data.objects if o.name not in before]
def Rx(t): c,s=math.cos(t),math.sin(t); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Ry(t): c,s=math.cos(t),math.sin(t); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
for name in only:
    k=KITS[name]; gid=k['gun']
    for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
    parts=imp(OUT+'/stf_head.glb')+imp(f'{OUT}/stf_{gid}.glb')
    tex={'body':f"stf_body_{k['body']}",'gear':f"stf_gear_{k['gear']}",'helm':f"stf_helm_{k['helm']}",'nvg':f"stf_helm_{k['helm']}",'head':f"stf_head_{k['face']}"}
    for o in parts:
        if o.type!='MESH': continue
        p=o.name.split('_STF')[0]
        if (p=='gear' and not k['vest']) or (p in('helm','nvg') and k['head']==0) or (p=='nvg' and k['head']<2) or (p=='glass' and k['lens']==0): o.hide_render=True; continue
        if p in tex:
            for sl in o.material_slots:
                for n in sl.material.node_tree.nodes:
                    if n.type=='TEX_IMAGE': n.image=bpy.data.images.load(D+tex[p]+'.jpg'); n.image.colorspace_settings.name='sRGB'
        if p=='glass':
            c=LENS[k['lens']]
            for sl in o.material_slots:
                b=sl.material.node_tree.nodes['Principled BSDF']
                for l in list(sl.material.node_tree.links): sl.material.node_tree.links.remove(l)
                b.inputs['Base Color'].default_value=(*c,1)
    H=json.load(open(OUT+'/ophold_stf.json'))[gid]
    before={o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=f'/mnt/user-data/outputs/changed-files/Resources/gun_{gid}.glb')
    names=[o.name for o in bpy.data.objects if o.name not in before]
    for n in names:
        if n.endswith(('_glove','_sleeve','_ARMS','_strap')): bpy.data.objects.remove(bpy.data.objects[n],do_unlink=True)
    new=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
    em=bpy.data.objects.new('gr',None); bpy.context.collection.objects.link(em)
    C=np.array([[1,0,0],[0,0,-1],[0,1,0]],float); Rg=Rx(H['al'])@Ry(H['phi']); Ra=C@Rg@C.T; pa=C@np.array(H['pos'])
    em.matrix_world=Matrix(((*Ra[0],pa[0]),(*Ra[1],pa[1]),(*Ra[2],pa[2]),(0,0,0,1)))
    for o in new:
        if o.parent is None: o.parent=em
    sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=40; sc.cycles.device='CPU'
    sc.render.film_transparent=True; sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'
    w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=3.2
    l=bpy.data.lights.new('s','SUN'); l.energy=3.5; lo=bpy.data.objects.new('s',l); bpy.context.collection.objects.link(lo); lo.rotation_euler=(0.8,0.25,2.5)
    l2=bpy.data.lights.new('r','SUN'); l2.energy=2.0; l2.color=(0.7,0.8,1.0); lo2=bpy.data.objects.new('r',l2); bpy.context.collection.objects.link(lo2); lo2.rotation_euler=(1.1,-0.3,-0.9)
    cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'
    sc.render.resolution_x=360; sc.render.resolution_y=280; sc.render.resolution_percentage=100
    cam.data.ortho_scale=74
    tg=bpy.data.objects.new('t',None); bpy.context.collection.objects.link(tg); tg.location=(0,6,164)
    cam.location=(-190,300,172)
    tr=cam.constraints.new('TRACK_TO'); tr.target=tg; tr.track_axis='TRACK_NEGATIVE_Z'; tr.up_axis='UP_Y'
    # aim the bust centre: shift camera along its right vector
    sc.render.filepath=f'{PO}/op_{name}.png'; bpy.ops.render.render(write_still=True)
    print('portrait',name)
