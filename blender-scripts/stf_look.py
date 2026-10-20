import bpy,sys,math
S='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/stf/Fbx/Special Task Force.blend'
bpy.ops.wm.open_mainfile(filepath=S)
arm=bpy.data.objects['rig']
names=[b.name for b in arm.data.bones]
print(len(names)); print([n for n in names if not n.startswith(('DEF','MCH','ORG'))][:80])
print([n for n in names if 'hand' in n.lower() or 'arm' in n.lower()][:60])
print('collections',[c.name for c in bpy.data.collections])
for o in bpy.data.objects:
    if o.name.startswith('cs_') or o.type=='EMPTY': o.hide_render=True; o.hide_viewport=True
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.cycles.device='CPU'
sc.render.resolution_x=900; sc.render.resolution_y=900
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True; w.node_tree.nodes['Background'].inputs[1].default_value=1.5
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); bpy.context.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=2.6
import mathutils
for nm,loc,rot in (('front',(0,-6,1.0),(90,0,0)),('side',(6,0,1.0),(90,0,90))):
    cam.location=loc; cam.rotation_euler=[math.radians(a) for a in rot]
    sc.render.filepath=f'/tmp/gunwork/stf_{nm}.png'; bpy.ops.render.render(write_still=True)
