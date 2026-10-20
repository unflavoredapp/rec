import sys; sys.path.insert(0,'/tmp/gunwork')
import pm_prep, numpy as np
parts,s=pm_prep.load()
for n,o in sorted(parts.items()):
    v=np.array([[p.co.x,-p.co.y,p.co.z] for p in o.data.vertices])  # x, back, up
    print(n,'centroid x%.1f back%.1f up%.1f'%tuple(v.mean(0)))
    for a,b in ((0,3),(3,8),(8,14),(14,20),(20,30)):
        m=(v[:,1]>=a)&(v[:,1]<b)
        if m.sum()>5: print('   back',a,b,'x',v[m,0].min().round(1),v[m,0].max().round(1),'up',v[m,2].min().round(1),v[m,2].max().round(1))
