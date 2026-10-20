import bpy
S='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/stf/Fbx/Special Task Force.blend'
bpy.ops.wm.open_mainfile(filepath=S)
for o in bpy.data.objects:
    d=o.dimensions
    extra=''
    if o.type=='MESH': extra=f"v={len(o.data.vertices)} mats={[m.name for m in o.data.materials if m]} vg={len(o.vertex_groups)} mods={[m.type for m in o.modifiers]} shapekeys={len(o.data.shape_keys.key_blocks) if o.data.shape_keys else 0}"
    if o.type=='ARMATURE': extra=f"bones={len(o.data.bones)}"
    print(o.type,o.name,'parent=',o.parent.name if o.parent else None,'loc',tuple(round(x,2) for x in o.location),'dim',tuple(round(x,2) for x in d),extra)
print([a.name for a in bpy.data.actions])
for m in bpy.data.materials:
    t=[n.image.name for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if m.use_nodes else []
    print('MAT',m.name,t)
