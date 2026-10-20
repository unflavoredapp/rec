import sys,math; sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L, numpy as np, bpy
from PIL import Image
r=L.load()
d=r.obj['Object_2']; o=d['o']; me=o.data; co=d['co']
for oo in bpy.data.objects:
    if oo.name.startswith('cs_') or oo.type in('EMPTY','ARMATURE') or oo.name.startswith('Object'): oo.hide_render=True
polys=me.polygons
cent=np.array([co[list(p.vertices)].mean(0) for p in polys]); mats=[me.materials[p.material_index].name for p in polys]
nvg=np.array([ (c[1]>18.2) for c in cent]); glass=np.array([m.startswith('SunGla') for m in mats])
print('faces',len(polys),'nvg',nvg.sum(),'glass',glass.sum())
cls=np.where(glass,2,np.where(nvg,1,0))
import bmesh
def part(k,col):
    bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.faces[i] for i in range(len(polys)) if cls[i]!=k],context='FACES')
    m2=bpy.data.meshes.new('p%d'%k); bm.to_mesh(m2); bm.free()
    for i in range(len(m2.vertices)): pass
    m2.vertices.foreach_set('co',[0]*0) if False else None
    ob=bpy.data.objects.new('p%d'%k,m2); bpy.context.collection.objects.link(ob)
    mt=bpy.data.materials.new('c%d'%k); mt.use_nodes=True; b=mt.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=col; b.inputs['Emission Color'].default_value=col; b.inputs['Emission Strength'].default_value=1
    m2.materials.clear(); m2.materials.append(mt); return ob,m2
# need transformed coords: write co into new meshes by vertex mapping -> simpler: transform object by tf in place
for k,col in ((0,(0.2,0.8,0.2,1)),(1,(1,0.1,0.1,1)),(2,(0.1,0.3,1,1))):
    ob,m2=part(k,col)
    # source mesh coords are blender-char space: apply same tf as L.tf
    for v in m2.vertices:
        p=np.array([-v.co.x,-v.co.y,v.co.z])*L.K; v.co=p
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=8; sc.cycles.device='CPU'
sc.render.resolution_x=600; sc.render.resolution_y=600
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=1
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=45
ims=[]
for loc,rot in (((0,300,176),(90,0,180)),((300,0,176),(90,0,90))):
    cam.location=loc; cam.rotation_euler=[math.radians(a) for a in rot]; sc.render.filepath='/tmp/gunwork/_c.png'; bpy.ops.render.render(write_still=True); ims.append(Image.open(sc.render.filepath).copy())
W=Image.new('RGB',(1200,600)); [W.paste(im,(i*600,0)) for i,im in enumerate(ims)]; W.save('/tmp/gunwork/stf_cls.png')
