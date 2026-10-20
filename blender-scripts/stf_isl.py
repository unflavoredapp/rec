import sys; sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L, numpy as np, bmesh
r=L.load()
def islands(name):
    d=r.obj[name]; me=d['o'].data; bm=bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    seen={}; comps=[]
    for v in bm.verts:
        if v.index in seen: continue
        k=len(comps); seen[v.index]=k; st=[v]; c=[]
        while st:
            a=st.pop(); c.append(a.index)
            for e in a.link_edges:
                w=e.other_vert(a)
                if w.index not in seen: seen[w.index]=k; st.append(w)
        comps.append(c)
    mats={}
    for f in bm.faces: mats.setdefault(seen[f.verts[0].index],set()).add(me.materials[f.material_index].name)
    return comps,mats
for name in ('Object_2','Object_1','Object_0'):
    comps,mats=islands(name); co=r.obj[name]['co']
    print(name,len(comps),'islands')
    for i,c in sorted(enumerate(comps),key=lambda t:-len(t[1]))[:25]:
        p=co[c]; print(' ',i,len(c),'x',p[:,0].min().round(0),p[:,0].max().round(0),'y',p[:,1].min().round(0),p[:,1].max().round(0),'z',p[:,2].min().round(0),p[:,2].max().round(0),mats[i])
