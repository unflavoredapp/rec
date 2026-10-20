import sys,math,json,os,collections; sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy, bmesh
import stf_lib as L, stf_pose as SP
OUT='/tmp/gunwork/stf_out'; os.makedirs(OUT,exist_ok=True)
BLADE=22
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
GUNS=[g for g in args if g!='head'] or list(SP.LEN)
r=L.load()
def faceparts():
    fp={}
    for n in ('Object_0','Object_1','Object_2'):
        d=r.obj[n]; me=d['o'].data; co=d['co']; cl={}
        for pi,p in enumerate(me.polygons):
            mn=me.materials[p.material_index].name
            if n=='Object_0': k='head' if mn.startswith('Head') else 'body'
            elif n=='Object_1': k='gear'
            else:
                k='glass' if mn.startswith('SunGla') else ('nvg' if (lambda c:(c[1]>18.2 or (c[1]>13.5 and c[2]>181.5)))(co[list(p.vertices)].mean(0)) else 'helm')
            cl.setdefault(k,[]).append(pi)
        fp[n]=cl
    return fp
FP=faceparts()
WHITE=None
def white_mat(name,rgba=(1,1,1,1)):
    global WHITE
    if WHITE is None:
        WHITE=bpy.data.images.new('white4',4,4); WHITE.pixels=[1.0]*64; WHITE.pack()
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; b=nt.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=rgba; b.inputs['Roughness'].default_value=0.85
    if rgba[3]<1: b.inputs['Alpha'].default_value=rgba[3]; m.blend_method='BLEND' if hasattr(m,'blend_method') else None
    t=nt.nodes.new('ShaderNodeTexImage'); t.image=WHITE; nt.links.new(t.outputs['Color'],b.inputs['Base Color'])
    return m
def loop_normals(me,ang=42):
    me.calc_loop_triangles()
    P=np.empty(len(me.vertices)*3); me.vertices.foreach_get('co',P); P=P.reshape(-1,3)
    key=lambda p: (round(p[0]*40),round(p[1]*40),round(p[2]*40))
    groups=collections.defaultdict(list); fn={}
    for p in me.polygons:
        vs=[P[v] for v in p.vertices]
        n=np.cross(vs[1]-vs[0],vs[2]-vs[0]) if len(vs)==3 else sum(np.cross(vs[i]-vs[0],vs[(i+1)%len(vs)]-vs[0]) for i in range(1,len(vs)-1))
        a=np.linalg.norm(n); fn[p.index]=(n/max(a,1e-12),a)
        for v in p.vertices: groups[key(P[v])].append(p.index)
    cs=math.cos(math.radians(ang)); out=np.zeros((len(me.loops),3))
    for p in me.polygons:
        n0=fn[p.index][0]
        for li in range(p.loop_start,p.loop_start+p.loop_total):
            v=me.loops[li].vertex_index; acc=np.zeros(3)
            for q in groups[key(P[v])]:
                nq,aq=fn[q]
                if nq@n0>=cs: acc+=nq*aq
            nn=np.linalg.norm(acc); out[li]=acc/nn if nn>1e-9 else n0
    return out
def make_part(objname,part,co,mat):
    src=r.obj[objname]['o'].data; keep=set(FP[objname].get(part,[]))
    if not keep: return None
    me=src.copy(); me.vertices.foreach_set('co',co.reshape(-1)); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
    dv=[v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm,geom=dv,context='VERTS')
    for lay in list(bm.verts.layers.deform): bm.verts.layers.deform.remove(lay)
    m2=bpy.data.meshes.new(part); bm.to_mesh(m2); bm.free()
    for k in list(m2.attributes.keys()):
        if k.startswith('sharp') : pass
    try: m2.free_normals_split()
    except Exception: pass
    m2.validate(verbose=True)
    print(part,'verts',len(m2.vertices))
    m2.materials.clear(); m2.materials.append(mat)
    for p in m2.polygons: p.use_smooth=True
    ln=loop_normals(m2)
    try: m2.normals_split_custom_set([tuple(x) for x in ln])
    except Exception as e: print('normals',e)
    ob=bpy.data.objects.new(part+'_STF',m2); bpy.context.collection.objects.link(ob); return ob
def clear():
    for o in list(bpy.data.objects):
        if o.name.endswith('_STF'): bpy.data.objects.remove(o,do_unlink=True)
def export(path,names):
    bpy.ops.object.select_all(action='DESELECT')
    for n in names: bpy.data.objects[n].select_set(True)
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',export_yup=True,export_apply=False,use_selection=True,export_materials='EXPORT',export_image_format='JPEG',export_cameras=False,export_lights=False)
mats={k:white_mat(k) for k in ('head','body','gear','helm','nvg')}
mats['glass']=white_mat('glass',(0.04,0.04,0.05,0.8))
holds={}
if 'head' in args or not args:
    Ts,hold,G,_=SP.solve(r,'m4',blade=BLADE,verbose=False)
    clear(); names=[]
    for part,on in (('head','Object_0'),('helm','Object_2'),('nvg','Object_2'),('glass','Object_2')):
        co=L.skin(r,on,Ts); ob=make_part(on,part,co,mats[part])
        if ob: names.append(ob.name)
    export(f'{OUT}/stf_head.glb',names); print('head',names)
for gid in GUNS:
    Ts,hold,G,(iR,iL)=SP.solve(r,gid,blade=BLADE)
    clear(); names=[]
    for part,on in (('body','Object_0'),('gear','Object_1')):
        co=L.skin(r,on,Ts); ob=make_part(on,part,co,mats[part]); names.append(ob.name)
    export(f'{OUT}/stf_{gid}.glb',names)
    holds[gid]=dict(al=hold['al'],phi=hold['phi'],pos=hold['pos'])
    print(gid,'ok',os.path.getsize(f'{OUT}/stf_{gid}.glb')//1024,'KB')
hp=f'{OUT}/ophold_stf.json'; old=json.load(open(hp)) if os.path.exists(hp) else {}
old.update(holds); json.dump(old,open(hp,'w'))
