import bpy
S='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/stf/Fbx/Special Task Force.blend'
bpy.ops.wm.open_mainfile(filepath=S)
arm=bpy.data.objects['rig']; o=bpy.data.objects['Object_0']
print([g.name for g in o.vertex_groups])
for n in ('arm.r','forearm.r','hand.r','shoulder.r'):
    b=arm.data.bones[n]; print(n,'parent',b.parent.name if b.parent else None,'head',tuple(round(x,3) for x in b.head_local),'tail',tuple(round(x,3) for x in b.tail_local))
print('constraints on pose bones:',sum(len(p.constraints) for p in arm.pose.bones), 'drivers', len(arm.animation_data.drivers) if arm.animation_data else 0)
print('rig loc/rot/scale',arm.location,arm.rotation_euler,arm.scale, 'mesh parent type',o.parent_type, o.matrix_world.translation)
